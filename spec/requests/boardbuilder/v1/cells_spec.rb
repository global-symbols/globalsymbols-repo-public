require 'rails_helper'

RSpec.describe BoardBuilder::V1::Cells, type: :request do

  before :each do
    @access_token = FactoryBot.create :doorkeeper_token, :with_boardbuilder_scopes
    @user = User.find(@access_token.resource_owner_id)
    @access_token_header = { 'Authorization': 'Bearer ' + @access_token.token }

    @board_set = FactoryBot.create :board_set, name: 'Maya', owner: @user, boards_count: 2
    @unowned_board_set = FactoryBot.create :board_set, name: 'Unowned', boards_count: 1
    @board = @board_set.boards.first
    @unowned_board = @unowned_board_set.boards.first
  end


  context 'with an existing Cell' do

    before :each do
      @cell = @board.cells.first
      @cell.update(linked_board: @board_set.boards.last)
      @unowned_cell = @unowned_board.cells.first
    end

    context 'GET /api/boardbuilder/v1/cells' do
      it 'returns an array of Cells for the specified Board' do
        get '/api/boardbuilder/v1/cells', params: { board_id: @board.id }, headers: @access_token_header

        expect(response.status).to eq(200)

        cells = JSON.parse(response.body)

        expect(cells.count).to eq @board.rows * @board.columns
        expect(cells[0]).to include @board.cells.first.slice('id', 'caption', 'background_colour', 'border_colour', 'text_colour', 'image_url')
        expect(cells[0]['linked_board_id']).to eq @cell.linked_board.id
        expect(cells[0]['created_at']).to be_a String
        expect(cells[0]['updated_at']).to be_a String
      end

      it 'does not return Cells owned by other users' do
        get '/api/boardbuilder/v1/cells', params: { board_id: @board.id }, headers: @access_token_header
        expect(response.body).to_not include @unowned_board_set.name
      end
    end

    context 'GET /api/boardbuilder/v1/cells/:id' do
      context 'Cell belongs to current_user' do
        it 'returns the specified Cell' do
          p @cell.inspect
          get "/api/boardbuilder/v1/cells/#{@cell.id}", headers: @access_token_header
          p response.body
          expect(response.status).to eq(200)
          board = JSON.parse(response.body)

          expect(board).to include @cell.reload.slice('id', 'caption', 'background_colour', 'border_colour', 'text_colour', 'image_url')
          expect(board['created_at']).to be_a String
          expect(board['updated_at']).to be_a String
        end

        it 'expands the parent Board' do
          get "/api/boardbuilder/v1/cells/#{@cell.id}", params: {expand: 'board'}, headers: @access_token_header
          expect(response.status).to eq(200)

          cell = JSON.parse(response.body)
          expect(cell['board']).to be_a Hash
          expect(cell['board']['id']).to eq @cell.board.id
        end
      end

      context 'Cell belongs to another user' do
        it 'returns 404' do
          get "/api/boardbuilder/v1/cells/#{@unowned_cell.id}", headers: @access_token_header

          expect(response.status).to eq(404)
        end

        context 'when the user is an admin' do
          before :each do
            @user.update! role: :admin
          end
          it 'returns 404' do
            get "/api/boardbuilder/v1/cells/#{@unowned_cell.id}", headers: @access_token_header
            expect(response.status).to eq(404)
          end
        end
      end
    end

    context 'PATCH /api/boardbuilder/v1/cells/:id' do
      context 'Cell belongs to current_user' do
        context 'with valid parameters' do
          it 'updates the Cell' do
            expect{
              patch "/api/boardbuilder/v1/cells/#{@cell.id}", params: {caption: 'Billy Board'}, headers: @access_token_header
            }.to change{@cell.reload.caption}.to('Billy Board')

            expect(response.status).to eq(200)

            board = JSON.parse(response.body)
            expect(board).to include @cell.slice('id', 'caption', 'background_colour', 'border_colour', 'text_colour', 'image_url')
            expect(board['created_at']).to be_a String
            expect(board['updated_at']).to be_a String
          end
        end

        context 'with invalid parameters' do
          # TODO: Invalid param testing when we have some validation on Cell.
          it 'does not update and returns 400' # do
            # expect{
            #   patch "/api/boardbuilder/v1/cells/#{@cell.id}", params: {caption: ''}, headers: @access_token_header
            # }.to_not change{@cell.reload}
            #
            # expect(response.status).to eq(400)
          # end
        end
      end

      context 'Cell belongs to another user' do
        it 'changes nothing, returns 404' do
          expect{
            patch "/api/boardbuilder/v1/cells/#{@unowned_cell.id}", params: {name: 'Billy Board Set'}, headers: @access_token_header
          }.to_not change{@unowned_cell.reload}
          expect(response.status).to eq(404)
        end
      end

    end

    context 'DELETE /api/boardbuilder/v1/cells/:id' do
      it 'does not allow deletion of Cells' do
        expect{
          delete "/api/boardbuilder/v1/cells/#{@cell.id}", headers: @access_token_header
        }.to change{Boardbuilder::Cell.count}.by 0

        expect(response.status).to eq(405)
      end
    end
  end

  context 'creation' do
    context 'POST /api/boardbuilder/v1/cells' do

      it 'does not allow creation of Cells' do
        expect{
          post "/api/boardbuilder/v1/cells", params: {board_id: @board.id, caption: 'My Cell'}, headers: @access_token_header
        }.to change{Boardbuilder::Cell.count}.by 0

        expect(response.status).to eq(405)
      end
    end
  end
end
