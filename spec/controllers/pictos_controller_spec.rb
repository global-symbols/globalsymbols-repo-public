require 'rails_helper'

RSpec.describe PictosController, type: :controller do
  
  before :each do
    @unauthorised_user = FactoryBot.create(:user)
  end
  
  describe "GET #show" do
    it "assigns the correct picto" do
      picto = FactoryBot.create(:picto, :with_published_symbolset)
      
      get :show, params: {id: picto.id, symbolset_id: picto.symbolset}
      expect(assigns(:picto)).to eq(picto)
    end

    it "renders the show template" do
      picto = FactoryBot.create(:picto, :with_published_symbolset)
      get :show, params: {id: picto.id, symbolset_id: picto.symbolset}
      expect(response).to render_template('show')
    end

    it "returns 404 for archived pictos" do
      picto = FactoryBot.create(:picto, :with_published_symbolset, archived: true)
      get :show, params: {id: picto.id, symbolset_id: picto.symbolset}
      expect(response).to have_http_status :unauthorized
    end
    
    it 'returns 404 for non-existent Pictos' do
      picto = FactoryBot.create(:picto, :with_published_symbolset)
      get :show, params: {id: 99999999, symbolset_id: picto.symbolset}
      expect(response).to have_http_status 404
      expect(response).to render_template('errors/not_found')
    end
    
    context 'when a file download is requested' do
      [OpenStruct.new({extension: 'png', mime_type: 'image/png'}),
       OpenStruct.new({extension: 'svg', mime_type: 'image/svg+xml'}),
       OpenStruct.new({extension: 'jpg', mime_type: 'image/jpeg'})].each do |format|
        context "a #{format.extension} file" do
          context "the Picto has a #{format.extension} file" do
            before :each do
              @picto = FactoryBot.create(:picto, :with_published_symbolset, images_file_format: format.extension)
              @image = @picto.images.first
              expect(@image.imagefile.file.extension.downcase).to eq format.extension
              expect(@picto.images.count).to eq 1
            end
            context 'download = 1' do
              it "downloads a #{format.extension} file to the client" do
                get :show, params: {id: @picto.id, symbolset_id: @picto.symbolset, format: format.extension, download: 1}
                expect(response).to have_http_status :success
                expect(response.headers['Content-Type']).to eq format.mime_type
                expect(response.headers['Content-Disposition']).to start_with 'attachment;'
                expect(response.body).to eq @image.imagefile.read
              end
            end

            context 'download = 0' do
              it "displays the #{format.extension} file" do
                get :show, params: {id: @picto.id, symbolset_id: @picto.symbolset, format: format.extension, download: 0}
                expect(response).to have_http_status :success
                expect(response.headers['Content-Type']).to eq format.mime_type
                expect(response.headers['Content-Disposition']).to start_with 'inline;'
                expect(response.body).to eq @image.imagefile.read
              end
            end
          end
          
          context "the Picto does not have a #{format.extension} file" do
            before :each do
              # Create the Picto Image.imagefile in a format  that is NOT format.extension
              @format = (format.extension == 'png') ? 'jpg' : 'png'
              expect(@format).to_not eq format.extension

              @picto = FactoryBot.create(:picto, :with_published_symbolset, images_file_format: @format)
              @image = @picto.images.first
              expect(@picto.images.count).to eq 1
              expect(@picto.images.first.imagefile.file.extension.downcase).to eq @format
              
              
              # @image = FactoryBot.create(:image, file_format: different_format)
              # @image.picto.symbolset.update!(status: :published)
              # Remove auto-generated image
              # @image.picto.images.where.not(@image).destroy
              # @picto = @image.picto
              # expect(@image.imagefile.file.extension.downcase).to eq format.extension
            end

            it 'returns 404' do
              get :show, params: {id: @picto.id, symbolset_id: @picto.symbolset, format: format.extension, download: 1}
              expect(response).to have_http_status :not_found
              expect(response.body).to eq ''
            end
          end
          
          # context 'the Picto is created with a SVG file' do
          #   it 'returns a converted PNG file' do
          #     image = FactoryBot.create(:image, file_format: 'svg')
          #     image.picto.symbolset.update!(status: :published)
          #     # picto = FactoryBot.create(:picto, :with_published_symbolset)
          #     expect(image.imagefile.file.extension.downcase).to eq 'svg'
          #
          #     get :show, params: {id: image.picto.id, symbolset_id: image.picto.symbolset, format: :png, download: 1}
          #     expect(response).to have_http_status :success
          #   end
          # end
        end
      end
    end
  end

  describe "GET #new" do
    context "for users authorised on the symbolset" do
      it "renders the new template for users who are a member of the symbolset" do
        symbolset = FactoryBot.create(:symbolset)
        sign_in symbolset.users.first
        get :new, params: {symbolset_id: symbolset}
        expect(response).to render_template('new')
      end
    end
    
    context "for users not authorised on the symbolset" do
      it "directs non-signed-in users to sign in" do
        get :new, params: {symbolset_id: FactoryBot.create(:symbolset)}
        expect(response).to redirect_to(new_user_session_path)
      end
  
      it "denies the action to non-members of the symbolset" do
        sign_in @unauthorised_user
        get :new, params: {symbolset_id: FactoryBot.create(:symbolset)}
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe "POST #create" do
    # include Rack::Test::Methods
    include ActionDispatch::TestProcess
    before :each do
      @symbolset = FactoryBot.create(:symbolset)
    end

    context "for users authorised on the symbolset" do
      before :each do
        imagefile  = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/picto.image.imagefile.png'), 'image/png')
        picto = FactoryBot.build(:picto, symbolset: @symbolset)
        @picto_attributes = picto.attributes
        @picto_attributes['images_attributes'] = [{imagefile:imagefile}]
        @picto_attributes['labels_attributes'] = [FactoryBot.build(:label, picto: picto).attributes]
    
        sign_in @symbolset.users.first
      end
      context "with valid attributes" do
        it "creates a new Picto" do
          expect{
            post :create, format: :javascript, params: { picto: @picto_attributes, symbolset_id: @symbolset }
          }.to change{ Picto.count }.by 1
        end
        
        it "creates a new Picto with the correct attributes and associated objects" do
          post :create, format: :javascript, params: { picto: @picto_attributes, symbolset_id: @symbolset }
          expect(assigns(:picto).labels.count).to eq 1
          expect(assigns(:picto).images.count).to eq 1

          #  Fails while automatic Concept creation is temporarily disabled
          # TODO: Re-enable automatic concept creation
          # expect(assigns(:picto).concepts.count).to eq 1
        end
        
        context 'when uploading an SVG' do
          before :each do
            imagefile  = Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/picto.image.imagefile.svg'), 'image/svg+xml')
            @picto_attributes['images_attributes'] = [{imagefile:imagefile}]
          end
          
          it "automatically generates an associated PNG file" do
            post :create, format: :javascript, params: { picto: @picto_attributes, symbolset_id: @symbolset }
            expect(assigns(:picto).images.last.imagefile.svg2png.file).to_not be_nil
          end
          
          # Large SVGs take ages to convert. Scale them down before conversion. Example cases...
          # <svg width="100%" height="100%" viewBox="0 0 6256.87 6260.19">
          # <svg width="10000px" height="10000px">
          it "handles SVGs with large canvas areas quickly"
        end
        
        it "automatically adds an associated Concept" do
          #  Fails while automatic Concept creation is temporarily disabled
          # TODO: Re-enable automatic concept creation
          # expect{
          #   post :create, format: :javascript, params: { picto: @picto_attributes, symbolset_id: @symbolset }
          # }.to change(Concept,:count).by 1
        end
    
        it "redirects to the new picto" do
          post :create, format: :javascript, params: { picto: @picto_attributes, symbolset_id: @symbolset }
          expect(response).to redirect_to symbolset_symbol_path(@symbolset, assigns(:picto))
        end
      end
  
      context "with invalid attributes" do
        before :each do
          # Make the picto_attributes invalid
          @picto_attributes['labels_attributes'] = []
        end
        it "renders the form" do
          post :create, format: :javascript, params: {picto: @picto_attributes, symbolset_id: @symbolset}
          expect(response).to render_template('create')
        end
      end
    end

    context "for users not authorised on the symbolset" do
      it "redirects unauthenticated visitors to sign in" do
        post :create, params: {picto: FactoryBot.build(:picto, symbolset: @symbolset).attributes, symbolset_id: @symbolset}
        expect(response).to redirect_to(new_user_session_path)
      end
  
      it "denies the action to non-members of the symbolset" do
        sign_in @unauthorised_user
        post :create, params: {picto: FactoryBot.build(:picto, symbolset: @symbolset).attributes, symbolset_id: @symbolset}
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe "GET #edit" do
    before :each do
      @symbolset = FactoryBot.create(:symbolset, :with_pictos)
    end
    
    context "for users authorised on the symbolset" do
      it "renders the edit form" do
        sign_in @symbolset.users.first
        get :edit, params: {id: @symbolset.pictos.first.id, symbolset_id: @symbolset }
        expect(response).to render_template('edit')
      end
    end
    
    context "for users not authorised on the symbolset" do
      it "redirects unauthenticated visitors to sign in" do
        get :edit, params: {id: @symbolset.pictos.first.id, symbolset_id: @symbolset }
        expect(response).to redirect_to(new_user_session_path)
      end
  
      it "denies the action to non-members of the symbolset" do
        sign_in @unauthorised_user
        get :edit, params: {id: @symbolset.pictos.first.id, symbolset_id: @symbolset }
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe "PUT #update" do
    before :each do
      symbolset = FactoryBot.create(:symbolset)
      @picto = FactoryBot.create(:picto, publisher_ref: 'Van', symbolset: symbolset)
    end

    context "for users authorised on the symbolset" do
      context "with valid attributes" do
        it "assigns the requested Picto" do
          sign_in @picto.symbolset.users.first
          put :update, params: {id: @picto, symbolset_id: @picto.symbolset,
                                picto: FactoryBot.attributes_for(:picto)}
          expect(assigns(:picto)).to eq(@picto)
        end
    
        it "updates the Picto with the specified attributes" do
          sign_in @picto.symbolset.users.first
          @picto.publisher_ref = 'Car'
          put :update, params: {id: @picto, symbolset_id: @picto.symbolset,
                                picto: @picto.attributes}
          @picto.reload
          expect(@picto.publisher_ref).to eq('Car')
        end
    
        it "redirects to the updated Picto" do
          sign_in @picto.symbolset.users.first
          put :update, params: {id: @picto, symbolset_id: @picto.symbolset,
                                picto: @picto.attributes}
          expect(response).to redirect_to symbolset_symbol_path(@picto.symbolset, @picto)
        end
      end
  
      context "with invalid attributes" do
        it "renders the form" do
          sign_in @picto.symbolset.users.first
          @picto.visibility = nil
          expect(@picto.valid?).to be false

          put :update, format: :javascript, params: {id: @picto, symbolset_id: @picto.symbolset,
                                picto: @picto.attributes}
          expect(response).to render_template('update')
        end
      end
    end

    context "for users not authorised on the symbolset" do
      it "redirects unauthenticated visitors to sign in" do
        put :update, params: {id: @picto, symbolset_id: @picto.symbolset.id, picto: FactoryBot.attributes_for(:picto)}
        expect(response).to redirect_to(new_user_session_path)
      end
  
      it "denies the action to non-members of the symbolset" do
        sign_in @unauthorised_user
        put :update, params: {id: @picto, symbolset_id: @picto.symbolset, picto: FactoryBot.attributes_for(:picto)}
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe "DELETE #delete" do
    before :each do
      symbolset = FactoryBot.create(:symbolset)
      @picto = FactoryBot.create(:picto, symbolset: symbolset)
    end

    context "for users authorised on the symbolset" do
      it "deletes the Picto" do
        sign_in @picto.symbolset.users.first
        expect{
          delete :destroy, params: {id: @picto.id, symbolset_id: @picto.symbolset}
        }.to change(Picto,:count).by(-1)
      end
  
      it "redirects to the symbolset" do
        sign_in @picto.symbolset.users.first
        delete :destroy, params: {id: @picto.id, symbolset_id: @picto.symbolset}
        expect(response).to redirect_to symbolset_path(@picto.symbolset)
      end
    end
    
    context "for users not authorised on the symbolset" do
      it "redirects unauthenticated visitors to sign in" do
        delete :destroy, params: {id: @picto.id, symbolset_id: @picto.symbolset}
        expect(response).to redirect_to(new_user_session_path)
      end
  
      it "denies the action to non-members of the symbolset" do
        sign_in @unauthorised_user
        delete :destroy, params: {id: @picto.id, symbolset_id: @picto.symbolset}
        expect(response).to have_http_status :unauthorized
      end
    end
  end
end
