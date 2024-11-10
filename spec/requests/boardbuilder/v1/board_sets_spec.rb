require 'rails_helper'

RSpec.describe BoardBuilder::V1::BoardSets, type: :request do

  before :each do
    @access_token = FactoryBot.create :doorkeeper_token, :with_boardbuilder_scopes
    @user = User.find(@access_token.resource_owner_id)
    @access_token_header = { 'Authorization': 'Bearer ' + @access_token.token }
  end


  context 'with an existing Board Set' do

    before :each do
      @board_set = FactoryBot.create :board_set, name: 'Maya', owner: @user, boards_count: 1
      @unowned_board_set = FactoryBot.create :board_set, name: 'Unowned', boards_count: 1
      @public_board_set = FactoryBot.create :board_set, name: 'Public', boards_count: 1, public: true
    end

    context 'GET /api/boardbuilder/v1/board_sets' do
      it 'returns an array of BoardSets for the current_user' do
        get '/api/boardbuilder/v1/board_sets', headers: @access_token_header

        expect(response.status).to eq(200)

        board_sets = JSON.parse(response.body)

        expect(board_sets.count).to eq 1
        expect(board_sets[0]).to include @board_set.reload.slice('id', 'name')
        expect(board_sets[0]['created_at']).to be_a String
        expect(board_sets[0]['updated_at']).to be_a String
      end

      it 'does not return BoardSets owned by other users' do
        get '/api/boardbuilder/v1/board_sets', headers: @access_token_header

        expect(response.body).to_not include @unowned_board_set.name
      end
    end

    context 'GET /api/boardbuilder/v1/board_sets/:id' do
      context 'BoardSet belongs to current_user' do
        it 'returns the specified BoardSet' do
          get "/api/boardbuilder/v1/board_sets/#{@board_set.id}", headers: @access_token_header

          expect(response.status).to eq(200)

          board_set = JSON.parse(response.body)
          expect(board_set).to include @board_set.reload.slice('id', 'name')
          expect(board_set['readonly']).to eq false
          expect(board_set['created_at']).to be_a String
          expect(board_set['updated_at']).to be_a String
        end

        it 'expands Boards' do
          get "/api/boardbuilder/v1/board_sets/#{@board_set.id}", params: {expand: 'boards'}, headers: @access_token_header
          expect(response.status).to eq(200)

          board_set = JSON.parse(response.body)
          expect(board_set['boards'].length).to be > 0
          expect(board_set['boards'][0]['id']).to eq @board_set.boards.first.id
        end
      end

      context 'BoardSet belongs to another user and is not public' do
        it 'returns 404' do
          get "/api/boardbuilder/v1/board_sets/#{@unowned_board_set.id}", headers: @access_token_header
          expect(response.status).to eq(404)
        end

        context 'when the user is an admin' do
          before :each do
            @user.update! role: :admin
          end
          it 'returns 404' do
            get "/api/boardbuilder/v1/board_sets/#{@unowned_board_set.id}", headers: @access_token_header
            expect(response.status).to eq(404)
          end
        end
      end

      context 'BoardSet belongs to another user and is public' do
        it 'returns the specified BoardSet' do
          get "/api/boardbuilder/v1/board_sets/#{@public_board_set.id}", headers: @access_token_header

          expect(response.status).to eq(200)

          board_set = JSON.parse(response.body)
          expect(board_set).to include @public_board_set.reload.slice('id', 'name')
          expect(board_set['readonly']).to eq true
          expect(board_set['created_at']).to be_a String
          expect(board_set['updated_at']).to be_a String
        end
      end
    end

    context 'PATCH /api/boardbuilder/v1/board_sets/:id' do
      context 'BoardSet belongs to current_user' do
        context 'with valid parameters' do
          it 'updates the BoardSet' do
            expect{
              patch "/api/boardbuilder/v1/board_sets/#{@board_set.id}", params: {name: 'Billy Board Set', opened_at: DateTime.tomorrow}, headers: @access_token_header
            }.to change{@board_set.reload.name}.to('Billy Board Set')
            .and change{@board_set.reload.opened_at}.to(DateTime.tomorrow)

            expect(response.status).to eq(200)

            board_set = JSON.parse(response.body)
            expect(board_set).to include @board_set.reload.slice('id', 'name')
            expect(board_set['opened_at']).to be_a String
            expect(board_set['created_at']).to be_a String
            expect(board_set['updated_at']).to be_a String
          end
        end

        context 'with invalid parameters' do
          it 'does not update and returns 400' do
            expect{
              patch "/api/boardbuilder/v1/board_sets/#{@board_set.id}", params: {name: ''}, headers: @access_token_header
            }.to_not change{@board_set.reload}

            expect(response.status).to eq(400)
          end
        end
      end

      context 'BoardSet belongs to another user' do
        context 'BoardSet is not public' do
          it 'returns 404' do
            expect{
              patch "/api/boardbuilder/v1/board_sets/#{@unowned_board_set.id}", params: {name: 'Billy Board Set'}, headers: @access_token_header
            }.to_not change{@unowned_board_set.reload}
            expect(response.status).to eq(404)
          end
        end

        context 'BoardSet is public' do
          it 'returns 403' do
            expect{
              patch "/api/boardbuilder/v1/board_sets/#{@public_board_set.id}", params: {name: 'Billy Board Set'}, headers: @access_token_header
            }.to_not change{@public_board_set.reload}
            expect(response.status).to eq(403)
          end
        end
      end

    end

    context 'DELETE /api/boardbuilder/v1/board_sets/:id' do
      context 'BoardSet belongs to current_user' do
        it 'deletes the BoardSet' do
          expect{
            delete "/api/boardbuilder/v1/board_sets/#{@board_set.id}", headers: @access_token_header
          }.to change(Boardbuilder::BoardSet, :count).by -1

          expect(response.status).to eq(204)
          expect(response.body).to eq ''
        end
      end

      context 'BoardSet belongs to another user' do
        context 'BoardSet is not public' do
          it 'returns 404' do
            expect{
              delete "/api/boardbuilder/v1/board_sets/#{@unowned_board_set.id}", headers: @access_token_header
            }.to_not change{@unowned_board_set.reload}
            expect(response.status).to eq(404)
          end

          context 'BoardSet is public' do
            it 'returns 403' do
              expect{
                delete "/api/boardbuilder/v1/board_sets/#{@public_board_set.id}", headers: @access_token_header
              }.to_not change{@public_board_set.reload}
              expect(response.status).to eq(403)
            end
          end
        end
      end
    end

    context 'GET /api/boardbuilder/v1/board_sets/featured' do
      before :each do
        @public_featured_board_set = FactoryBot.create :board_set, name: 'Public', public: true, featured_level: 1, boards_count: 1
        @private_featured_board_set = FactoryBot.create :board_set, name: 'Private', public: false, featured_level: 1, boards_count: 1
        @unfeatured_board_set = FactoryBot.create :board_set, name: 'Billy', public: false, featured_level: nil, boards_count: 1
      end

      it 'returns an array of featured BoardSets' do
        get '/api/boardbuilder/v1/board_sets/featured', headers: @access_token_header

        expect(response.status).to eq(200)

        board_sets = JSON.parse(response.body)
        expect(board_sets.count).to eq 1
        expect(board_sets[0]).to include @public_featured_board_set.reload.slice('id', 'name')
        expect(board_sets[0]['readonly']).to eq true
        expect(board_sets[0]['created_at']).to be_a String
        expect(board_sets[0]['updated_at']).to be_a String
      end

      it 'does not return non-featured or non-public BoardSets' do
        get '/api/boardbuilder/v1/board_sets', headers: @access_token_header

        expect(response.status).to eq(200)

        expect(response.body).to_not include @private_featured_board_set.name
        expect(response.body).to_not include @unfeatured_board_set.name
      end
    end
  end

  context 'creation' do
    context 'POST /api/boardbuilder/v1/board_sets' do

      context 'with valid parameters' do
        it 'creates a new BoardSet' do
          expect{
            post "/api/boardbuilder/v1/board_sets", params: {name: 'Maya Board Set'}, headers: @access_token_header
          }.to change(Boardbuilder::BoardSet, :count).by 1

          expect(response.status).to eq(201)

          board_set = JSON.parse(response.body)

          expect(board_set['id']).to be_an Integer
          expect(board_set['name']).to eq 'Maya Board Set'
          expect(board_set['created_at']).to be_a String
          expect(board_set['updated_at']).to be_a String

          board_set_user = Boardbuilder::BoardSet.last.board_set_users.first

          expect(board_set_user.role).to eq 'owner'
          expect(board_set_user.user).to eq @user
        end

        it 'assigns the authenticated user as the BoardSet owner' do
          post "/api/boardbuilder/v1/board_sets", params: {name: 'Maya Board Set'}, headers: @access_token_header
          board_set_response = JSON.parse(response.body)
          board_set = Boardbuilder::BoardSet.find(board_set_response['id'])
          expect(board_set.users.count).to eq 1
          expect(board_set.users).to include @user
          expect(board_set.board_set_users.first.role).to eq 'owner'
        end

        context 'with nested Boards and Cells' do
          it 'creates a new BoardSet with the specified Boards and Cells' do
            params = {
              name: 'Maya Board Set',
              boards: [{
                name: 'First Board',
                rows: 1,
                columns: 2,
                cells: [
                    { caption: 'First Cell' },
                    { caption: 'Second Cell' }
                ]
              }]
            }

            expect{
              post "/api/boardbuilder/v1/board_sets", params: params, headers: @access_token_header
              p response.body
              expect(response.status).to eq(201)
            }.to change(Boardbuilder::BoardSet, :count).by(1)
            .and change(Boardbuilder::Board, :count).by(1)
            .and change(Boardbuilder::Cell, :count).by(2)

            expect(Boardbuilder::Board.last.cells.count).to eq 2
            expect(Boardbuilder::Board.last.cells.first.caption).to eq 'First Cell'
            expect(Boardbuilder::Board.last.cells.last.caption).to eq 'Second Cell'
          end
        end
      end

      context 'with invalid parameters' do
        it 'does not save and returns 400' do
          expect{
            post "/api/boardbuilder/v1/board_sets", params: {name: ''}, headers: @access_token_header
          }.to change(Boardbuilder::BoardSet, :count).by 0

          expect(response.status).to eq(400)
        end
      end
    end
  end
end
