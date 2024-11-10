require 'rails_helper'

RSpec.describe BoardBuilder::V1::Media, type: :request do

  include ActionDispatch::TestProcess::FixtureFile

  before :all do
    @file_file_upload = fixture_file_upload('picto.image.imagefile.png', 'image/png')
    @canvas_file_upload = fixture_file_upload('board_builder.media.canvas.json', 'application/json')
    @changed_canvas_file_upload = fixture_file_upload('board_builder.media.canvas.changed.json', 'application/json')
  end

  before :each do
    @access_token = FactoryBot.create :doorkeeper_token, :with_boardbuilder_scopes
    @user = User.find(@access_token.resource_owner_id)
    @access_token_header = { 'Authorization': 'Bearer ' + @access_token.token }
  end

  context 'creation' do
    context 'POST /api/boardbuilder/v1/media' do
      it 'creates a new Media belonging to the current user' do
        expect{
          post "/api/boardbuilder/v1/media", params: {file: @file_file_upload, canvas: @canvas_file_upload}, headers: @access_token_header
        }.to change{Boardbuilder::Media.count}.by 1

        expect(response.status).to eq(201)
        media = JSON.parse(response.body)
        expect(media['user_id']).to eq @user.id
        expect(media['canvas_url']).to be_a String
        expect(media['canvas_url'].length).to be > 50
      end
    end
  end

  context 'with existing Media' do
    before :each do
      @owned_media = FactoryBot.create(:media, caption: 'Owned Media', user: @user)
      @unowned_media = FactoryBot.create(:media, caption: 'Unowned Media')
    end

    context 'GET /api/boardbuilder/v1/media' do
      it 'returns a list of Media owned by the current user' do
        get "/api/boardbuilder/v1/media", headers: @access_token_header
        expect(response.status).to eq(200)

        media = JSON.parse(response.body)
        expect(media.count).to eq 1
        expect(media[0]).to include @owned_media.reload.slice('id', 'user_id', 'format', 'caption', 'height', 'width', 'filesize')
        expect(media[0]['created_at']).to be_a String
        expect(media[0]['updated_at']).to be_a String
      end

      it 'does not return Media owned by other users' do
        get '/api/boardbuilder/v1/media', headers: @access_token_header
        expect(response.status).to eq(200)
        expect(response.body).to include @owned_media.caption
        expect(response.body).to_not include @unowned_media.caption
      end
    end

    context 'GET /api/boardbuilder/v1/media/:id' do
      context 'Media belongs to the current_user' do
        context 'Media has no canvas' do
          it 'returns the requested Media' do
            get "/api/boardbuilder/v1/media/#{@owned_media.id}", headers: @access_token_header
            expect(response.status).to eq(200)

            media = JSON.parse(response.body)
            expect(media).to include @owned_media.reload.slice('id', 'user_id', 'format', 'caption', 'height', 'width', 'filesize')
            expect(media['canvas_url']).to eq nil
            expect(media['created_at']).to be_a String
            expect(media['updated_at']).to be_a String
          end
        end

        context 'Media has a canvas' do
          before :each do
            @owned_media.update(canvas: @canvas_file_upload)
          end
          it 'returns the requested Media' do
            get "/api/boardbuilder/v1/media/#{@owned_media.id}", headers: @access_token_header
            expect(response.status).to eq(200)

            media = JSON.parse(response.body)
            expect(media).to include @owned_media.reload.slice('id', 'user_id', 'format', 'caption', 'height', 'width', 'filesize', 'canvas_url')
            expect(media['canvas_url']).to be_a String
            expect(media['canvas_url'].length).to be > 50
            expect(media['created_at']).to be_a String
            expect(media['updated_at']).to be_a String
          end
        end
      end


      context 'Media does not belong to the current_user' do
        it 'returns 404' do
          get "/api/boardbuilder/v1/media/#{@unowned_media.id}", headers: @access_token_header
          expect(response.status).to eq(404)
          expect(response.body).to_not include @owned_media.caption
          expect(response.body).to_not include @unowned_media.caption
        end
      end
    end

    context 'PATCH /api/boardbuilder/v1/media/:id' do
      context 'Media belongs to the current_user' do
        context 'Media has no canvas' do
          it 'updates the requested Media and returns the Media' do
            expect {
              patch "/api/boardbuilder/v1/media/#{@owned_media.id}", params: {file: @file_file_upload, caption: 'New Caption'}, headers: @access_token_header
              # puts response.body
            }.to change{@owned_media.reload.caption}.from('Owned Media').to('New Caption')
            # .and change{@owned_media.reload.file.url}

            expect(response.status).to eq(200)
            media = JSON.parse(response.body)
            expect(media).to include @owned_media.reload.slice('id', 'user_id', 'format', 'caption', 'height', 'width', 'filesize')
            expect(media['public_url']).to be_a String
            expect(media['created_at']).to be_a String
            expect(media['updated_at']).to be_a String
          end
        end

        context 'Media has a canvas' do
          before :each do
            @owned_media.update(canvas: @changed_canvas_file_upload)
          end
          it 'updates the requested Media and returns the Media' do
            # Race condition in testing?
            # When conducted in isolation, this test passes.
            # When conducated as part of a suite or wider context, this test fails because @owned_media.caption does not change.
            # Async upload/commit by Carrierwave?
            expect {
              patch "/api/boardbuilder/v1/media/#{@owned_media.id}", params: {file: @file_file_upload, canvas: @changed_canvas_file_upload, caption: 'New Caption'}, headers: @access_token_header
            }.to change{@owned_media.reload.caption}.from('Owned Media').to('New Caption')
            # .and change{@owned_media.reload.canvas.url}
            # .and change{@owned_media.reload.file.url}

            expect(response.status).to eq(200)
            media = JSON.parse(response.body)
            expect(media).to include @owned_media.reload.slice('id', 'user_id', 'format', 'caption', 'height', 'width', 'filesize')
            expect(media['public_url']).to be_a String
            expect(media['canvas_url']).to be_a String
            expect(media['canvas_url'].length).to be > 20
            expect(media['created_at']).to be_a String
            expect(media['updated_at']).to be_a String
          end
        end

      end

      context 'Media does not belong to the current_user' do
        it 'returns 403' do
          expect {
            patch "/api/boardbuilder/v1/media/#{@unowned_media.id}", params: {caption: 'New Caption'}, headers: @access_token_header
            pp response.body
          }.to_not change{@unowned_media.reload.caption}

          expect(response.status).to eq(403)
        end
      end
    end

    context 'DELETE /api/boardbuilder/v1/media/:id' do
      context 'Media belongs to the current_user' do
        it 'deletes the Media item' do
          expect {
            delete "/api/boardbuilder/v1/media/#{@owned_media.id}", headers: @access_token_header
          }.to change(Boardbuilder::Media, :count).by(-1)

          expect(response.status).to eq(204)
        end
      end

      context 'Media does not belong to the current_user' do
        it 'returns 403' do
          expect {
            delete "/api/boardbuilder/v1/media/#{@unowned_media.id}", headers: @access_token_header
            pp response.body
          }.to_not change(Boardbuilder::Media, :count)

          expect(response.status).to eq(403)
        end
      end
    end
  end
end
