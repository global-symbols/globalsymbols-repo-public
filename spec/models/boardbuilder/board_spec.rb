require 'rails_helper'

RSpec.describe Boardbuilder::Board, type: :model do
  context 'with minimum parameters' do
    it 'creates a private Board' do
      board = FactoryBot.create(:board, name: 'My Board')

      expect(board.name).to eq('My Board')
    end


  end

  describe 'populate_cells' do
    before :each do
      @board = FactoryBot.create(:board, rows: 2, columns: 2)
      expect(@board.cells.count).to eq @board.rows * @board.columns
    end

    it 'populates new Boards with (rows x columns) Cells' do
      expect(@board.cells.count).to eq 4
    end

    it 'assigns the correct indexes to Cells' do
      expect(@board.cells.pluck :index).to eq [1, 2, 3, 4]
    end

    context 'increasing the rows or columns' do
      it 'increases the number of Cells accordingly' do
        expect{
          @board.update!(rows: 3)
        }.to change{@board.cells.count}.from(4).to(6)
      end
    end

    context 'decreasing the rows or columns' do
      it 'decreases the number of Cells accordingly' do
        expect{
          @board.update!(rows: 1)
        }.to change{@board.cells.count}.from(4).to(2)
      end

      it 'destroys the last Cells in the list' do
        first_two_cell_ids = @board.cells.first(2).pluck :id
        last_two_cell_ids  = @board.cells.last(2).pluck :id

        # Remove two cells by changing rows to 1
        # The first two cells should remain, and the last two be deleted.
        expect{
          @board.update!(rows: 1)
        }.to change{@board.cells.reload.where(id:  last_two_cell_ids).count}.by(-2)
        .and change{@board.cells.reload.where(id: first_two_cell_ids).count}.by(0)
      end
    end

    context 'making no change to the number of Cells' do
      it 'does not change the number of Cells' do
        expect{
          @board.update!(rows: 1, columns: 4)
        }.to change{@board.cells.count}.by(0)

        expect{
          @board.update!(rows: 2, columns: 2)
        }.to change{@board.cells.count}.by(0)
      end
    end
  end

  describe 'validations' do
    it 'is invalid without a name' do
      expect{FactoryBot.create(:board, name: nil)}.to raise_exception ActiveRecord::RecordInvalid
    end

    describe 'captions_position field' do
      it 'is invalid without a captions_position' do
        expect{FactoryBot.create(:board, captions_position: nil)}.to raise_exception ActiveRecord::RecordInvalid
      end
    end

    describe 'columns field' do
      it 'is invalid without a number of columns' do
        expect{FactoryBot.create(:board, columns: nil)}.to raise_exception ActiveRecord::RecordInvalid
      end
      it 'is invalid with less than 1 column' do
        expect{FactoryBot.create(:board, columns: 0)}.to raise_exception ActiveRecord::RecordInvalid
      end
      it 'is valid with a positive integer' do
        expect{FactoryBot.create(:board, columns: 1)}.to change(Boardbuilder::Board, :count).by 1
      end
    end

    describe 'rows field' do
      it 'is invalid without a number of rows' do
        expect{FactoryBot.create(:board, rows: nil)}.to raise_exception ActiveRecord::RecordInvalid
      end
      it 'is invalid with less than 1 row' do
        expect{FactoryBot.create(:board, rows: 0)}.to raise_exception ActiveRecord::RecordInvalid
      end
      it 'is valid with a positive integer' do
        expect{FactoryBot.create(:board, rows: 1)}.to change(Boardbuilder::Board, :count).by 1
      end
    end
  end
end
