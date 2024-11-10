require 'rails_helper'

RSpec.describe BoardBuilder::V1::Boards, type: :request do

  before :each do
    @access_token = FactoryBot.create :doorkeeper_token, :with_boardbuilder_scopes
    @user = User.find(@access_token.resource_owner_id)
    @access_token_header = { 'Authorization': 'Bearer ' + @access_token.token }

    @board_set = FactoryBot.create :board_set, name: 'Maya', owner: @user, boards_count: 1
    @unowned_board_set = FactoryBot.create :board_set, name: 'Unowned', boards_count: 1
  end


  context 'with an existing Board' do

    before :each do
      @board = @board_set.boards.first
      @unowned_board = @unowned_board_set.boards.first
    end

    context 'GET /api/boardbuilder/v1/boards' do
      it 'returns an array of Boards for the specified BoardSet' do
        get '/api/boardbuilder/v1/boards', params: { board_set_id: @board_set.id }, headers: @access_token_header

        expect(response.status).to eq(200)

        boards = JSON.parse(response.body)

        expect(boards.count).to eq 1
        expect(boards[0]).to include @board.reload.slice('id', 'name', 'captions_position', 'columns', 'rows')
        expect(boards[0]['created_at']).to be_a String
        expect(boards[0]['updated_at']).to be_a String
      end

      it 'does not return Boards owned by other users' do
        get '/api/boardbuilder/v1/boards', headers: @access_token_header
        expect(response.body).to_not include @unowned_board_set.name
      end
    end

    context 'GET /api/boardbuilder/v1/boards/:id' do
      context 'Board belongs to current_user' do
        it 'returns the specified Board' do
          get "/api/boardbuilder/v1/boards/#{@board.id}", headers: @access_token_header

          expect(response.status).to eq(200)
          board = JSON.parse(response.body)

          expect(board).to include @board.reload.slice('id', 'name', 'captions_position', 'columns', 'rows')
          expect(board['created_at']).to be_a String
          expect(board['updated_at']).to be_a String
        end

        it 'expands Cells' do
          get "/api/boardbuilder/v1/boards/#{@board.id}", params: {expand: 'cells'}, headers: @access_token_header
          expect(response.status).to eq(200)

          board = JSON.parse(response.body)
          expect(board['cells'].length).to be > 0
          expect(board['cells'][0]['id']).to eq @board.cells.first.id
        end

        it 'expands the parent BoardSet' do
          get "/api/boardbuilder/v1/boards/#{@board.id}", params: {expand: 'board_set'}, headers: @access_token_header
          expect(response.status).to eq(200)

          board = JSON.parse(response.body)
          expect(board['board_set']).to be_a Hash
          expect(board['board_set']['id']).to eq @board.board_set.id
        end
      end

      context 'Board belongs to another user' do
        it 'returns 404' do
          get "/api/boardbuilder/v1/boards/#{@unowned_board_set.boards.first.id}", headers: @access_token_header

          expect(response.status).to eq(404)
        end

        context 'when the user is an admin' do
          before :each do
            @user.update! role: :admin
          end
          it 'returns 404' do
            get "/api/boardbuilder/v1/boards/#{@unowned_board_set.boards.first.id}", headers: @access_token_header
            expect(response.status).to eq(404)
          end
        end
      end
    end

    context 'PATCH /api/boardbuilder/v1/boards/:id' do
      context 'Board belongs to current_user' do
        context 'with valid parameters' do
          it 'updates the Board' do
            expect{
              patch "/api/boardbuilder/v1/boards/#{@board.id}", params: {name: 'Billy Board'}, headers: @access_token_header
              expect(response.status).to eq(200)
            }.to change{@board.reload.name}.to 'Billy Board'

            board = JSON.parse(response.body)
            expect(board).to include @board.reload.slice('id', 'name', 'captions_position', 'columns', 'rows')
            expect(board['created_at']).to be_a String
            expect(board['updated_at']).to be_a String
          end
        end

        context 'with invalid parameters' do
          it 'does not update and returns 400' do
            expect{
              patch "/api/boardbuilder/v1/boards/#{@board.id}", params: {name: ''}, headers: @access_token_header
            }.to_not change{@board_set.reload}

            expect(response.status).to eq(400)
          end
        end
      end

      context 'Board belongs to another user' do
        it 'returns 404' do
          expect{
            patch "/api/boardbuilder/v1/boards/#{@unowned_board.id}", params: {name: 'Billy Board Set'}, headers: @access_token_header
          }.to_not change{@unowned_board_set.reload}
          expect(response.status).to eq(404)
        end
      end

    end

    context 'DELETE /api/boardbuilder/v1/boards/:id' do
      context 'Board belongs to current_user' do
        it 'deletes the Board and associated Cells' do
          expect{
            delete "/api/boardbuilder/v1/boards/#{@board.id}", headers: @access_token_header
            pp response.body
          }.to change(Boardbuilder::Board, :count).by(-1)
          .and change(Boardbuilder::Cell, :count).by(-(@board.columns * @board.rows))

          expect(response.status).to eq(204)
          expect(response.body).to eq ''
        end
      end

      context 'Board belongs to another user' do
        it 'returns 404' do
          expect{
            delete "/api/boardbuilder/v1/boards/#{@unowned_board.id}", headers: @access_token_header
          }.to_not change{@unowned_board_set.reload}
          expect(response.status).to eq(404)
        end
      end
    end

    context 'PATCH /api/boardbuilder/v1/boards/:id/reorder_cells' do
      context 'Board belongs to current_user' do
        before :each do
          @original_cells_order = @board.cells.order(index: :asc).pluck(:id)
          @reversed_cells_order = @board.cells.order(index: :desc).pluck(:id)
        end
        context 'with valid parameters' do
          it 'Reorders the Cells' do
            expect{
              patch "/api/boardbuilder/v1/boards/#{@board.id}/reorder_cells", params: {cell_ids: @reversed_cells_order}, headers: @access_token_header
            }.to change{@board.cells.reload.order(index: :asc).pluck(:id)}.from(@original_cells_order).to(@reversed_cells_order)
          end

          it 'responds with 200 OK' do
            patch "/api/boardbuilder/v1/boards/#{@board.id}/reorder_cells", params: {cell_ids: @reversed_cells_order}, headers: @access_token_header
            expect(response.status).to eq(200)
          end
        end

        context 'with a Cell belonging to another Board' do
          context 'of another User' do
            before :each do
              @unowned_detached_cell = FactoryBot.create(:board_set, boards_count: 1).boards.first.cells.first
              @reversed_cells_order << @unowned_detached_cell.id
            end

            it 'returns 404' do
              expect{
                patch "/api/boardbuilder/v1/boards/#{@board.id}/reorder_cells", params: {cell_ids: @reversed_cells_order}, headers: @access_token_header
              }.to_not change{Boardbuilder::Cell.all.pluck(:updated_at)}
              expect(response.status).to eq(404)
            end
          end

          context 'of the Board owner' do
            before :each do
              @owned_detached_cell = FactoryBot.create(:board_set, owner: @user, boards_count: 1).boards.first.cells.first
              @reversed_cells_order << @owned_detached_cell.id
            end

            it 'returns 404' do
              expect{
                patch "/api/boardbuilder/v1/boards/#{@board.id}/reorder_cells", params: {cell_ids: @reversed_cells_order}, headers: @access_token_header
              }.to_not change{Boardbuilder::Cell.all.pluck(:updated_at)}
              expect(response.status).to eq(404)
            end
          end

        end
      end

      context 'Board belongs to another user' do
        before :each do
          @original_cells_order = @unowned_board.cells.order(index: :asc)
          @reversed_cells_order = @unowned_board.cells.order(index: :desc).pluck(:id)
        end
        it 'does not reorder the Cells' do
          expect{
            patch "/api/boardbuilder/v1/boards/#{@unowned_board.id}/reorder_cells", params: {cell_ids: @reversed_cells_order}, headers: @access_token_header
          }.to_not change{@original_cells_order.reload}
        end
        it 'returns 404' do
          patch "/api/boardbuilder/v1/boards/#{@unowned_board.id}/reorder_cells", params: {cell_ids: @reversed_cells_order}, headers: @access_token_header
          expect(response.status).to eq(404)
        end
      end
    end

  end

  context 'creation' do
    context 'POST /api/boardbuilder/v1/boards' do

      context 'with valid parameters' do
        it 'creates a new Board' do
          expect{
            post "/api/boardbuilder/v1/boards", params: {board_set_id: @board_set.id, name: 'Maya Board'}, headers: @access_token_header
            pp response.body
          }.to change(Boardbuilder::Board, :count).by 1

          expect(response.status).to eq(201)

          board = JSON.parse(response.body)

          expect(board['id']).to be_an Integer
          expect(board['name']).to eq 'Maya Board'
          expect(board['created_at']).to be_a String
          expect(board['updated_at']).to be_a String
        end

        context 'with nested Cells' do
          it 'creates a new Board with the specified Cells' do
            params = {
                name: 'Maya Board',
                board_set_id: @board_set.id,
                rows: 1,
                columns: 2,
                cells: [
                    { caption: 'First Cell' },
                    { caption: 'Second Cell' }
                ]
            }

            expect{
              post "/api/boardbuilder/v1/boards", params: params, headers: @access_token_header
              p response.body
              expect(response.status).to eq(201)
            }.to change(Boardbuilder::Board, :count).by(1)
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
            post "/api/boardbuilder/v1/boards", params: {board_set_id: @board_set.id, name: ''}, headers: @access_token_header
          }.to change(Boardbuilder::Board, :count).by 0

          expect(response.status).to eq(400)
        end
      end
    end

    context 'POST /api/boardbuilder/v1/boards/obf' do

      before :each do

        @obf = File.open(Rails.root.join('spec/fixtures/obf_with_embedded_base64_images.obf')).readlines.map(&:chomp).join
      end

      context 'BoardSet belongs to current_user' do
        it 'Returns a new Board within the BoardSet' do
          expect{
            post "/api/boardbuilder/v1/boards/obf", params: { obf: @obf, board_set_id: @board_set.id }, headers: @access_token_header
          }.to change(Boardbuilder::Board, :count).by(1)
          .and change(Boardbuilder::Cell, :count).by(6)
          .and change(Boardbuilder::Media, :count).by(2)
          .and change{@board_set.boards.reload.count}.by(1)

          expect(response.status).to eq(201)

          board = JSON.parse(response.body)

          expect(board['board_set_id']).to eq @board_set.id
        end
      end

      context 'BoardSet belongs to another user' do
        it 'Returns 404 Unauthorised' do
          expect{
            post "/api/boardbuilder/v1/boards/obf", params: { obf: @obf, board_set_id: @unowned_board_set.id }, headers: @access_token_header
          }.to change(Boardbuilder::Board, :count).by(0)
          .and change(Boardbuilder::Cell, :count).by(0)
          .and change(Boardbuilder::Media, :count).by(0)
          .and change{@unowned_board_set.boards.reload.count}.by(0)

          expect(response.status).to eq(404)
        end
      end
    end
  end
end
