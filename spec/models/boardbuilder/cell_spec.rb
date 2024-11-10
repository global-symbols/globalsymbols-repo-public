require 'rails_helper'

RSpec.describe Boardbuilder::Cell, type: :model do
  context 'with minimum parameters' do
    it 'creates a Cell' do
      cell = FactoryBot.create(:cell, caption: 'My Cell')

      expect(cell.caption).to eq('My Cell')
    end

    describe 'index numbering' do
      before :each do
        @board = FactoryBot.create :board, rows: 2, columns: 2
      end

      it 'sets sequential index numbers for each Cell in a new Board' do
        expect(@board.cells.pluck :index).to eq [1,2,3,4]
      end

      it 'appends sequential index numbers when Cells are added to the Board' do
        @board.update!(columns: 3)
        expect(@board.cells.pluck :index).to eq [1,2,3,4,5,6]
      end
    end
  end

  describe 'validations' do
    before :each do
      @board_set = FactoryBot.create :board_set, boards_count: 2
      @board = @board_set.boards.first
      @cell = @board.cells.first
      @cell.update!(caption: 'before')
      expect(@cell).to be_valid
    end
    it 'is valid without a caption' do
      expect{@cell.update!(caption: nil)}.to change{@cell.reload.caption}.from('before').to(nil)
    end

    describe 'linked_board' do
      it 'is valid when set to another Board within the Board Set' do
        expect{@cell.update!(linked_board: @board_set.boards.last)}.to_not raise_exception
        expect(@cell.linked_board).to eq @board_set.boards.last
      end

      it 'is invalid when set to a Board outside the Board Set' do
        outside_board_set = FactoryBot.create :board_set, boards_count: 1
        expect{@cell.update!(linked_board: outside_board_set.boards.last)}.to raise_exception ActiveRecord::RecordInvalid
      end

      it 'is invalid when set to the same Board as the Cell' do
        expect{@cell.update!(linked_board: @cell.board)}.to raise_exception ActiveRecord::RecordInvalid
      end

      context 'with a tree of linked boards' do
        before :each do
          @grandfather_board = FactoryBot.create :board, board_set: @board_set
          @father_board = FactoryBot.create :board, board_set: @board_set
          @child_board = FactoryBot.create :board, board_set: @board_set
          @father_board.cells.first.update(linked_board: @grandfather_board)
          @child_board.cells.first.update(linked_board: @father_board)

          # Check that we can walk up the tree to the grandfather_board
          expect(@child_board.cells.first.linked_board).to eq @father_board
          expect(@child_board.cells.first.linked_board.cells.first.linked_board).to eq @grandfather_board
        end

        it 'is invalid when linked_board is any ancestor Board of the Cell' do
          # Try to assign ancestors as the descendent of child_board
          expect{@child_board.cells.last.update!(linked_board: @child_board)}.to raise_exception ActiveRecord::RecordInvalid
          expect{@child_board.cells.last.update!(linked_board: @father_board)}.to raise_exception ActiveRecord::RecordInvalid
          expect{@child_board.cells.last.update!(linked_board: @grandfather_board)}.to raise_exception ActiveRecord::RecordInvalid
        end

        it 'is invalid when linked_board is any descendent Board of the Cell\'s Board' do
          expect{@grandfather_board.cells.first.update!(linked_board: @child_board)}.to raise_exception ActiveRecord::RecordInvalid
        end

        it 'allows the Cell to be saved with no change to the linked_board' do
          # Try to update the child_board with the same linked_board
          expect{
            @child_board.cells.first.update!(caption: 'hurrah', linked_board: @father_board)
          }.to change{@child_board.cells.first.caption}.to 'hurrah'
        end

        it 'passes validation when removing a linked_board' do
          # Remove the child's linked board
          expect{
            @child_board.cells.first.update!(linked_board: nil)
          }.to change{@child_board.cells.first.linked_board}.to nil
        end
      end
    end

    describe 'picto_id and boardbuilder_media_id' do
      it 'prevents picto_id AND media_id from being set at the same time' do
        expect{
          @cell.update!(picto: FactoryBot.create(:picto), media: FactoryBot.create(:media))
        }.to raise_exception ActiveRecord::RecordInvalid
      end

      it 'allows picto_id to be set when media_id is empty' do
        picto = FactoryBot.create(:picto)
        @cell.update!(picto: picto, media: nil)
        expect(@cell.picto).to eq picto
        expect(@cell.media).to be_nil
      end

      it 'allows media_id to be set when picto_id is empty' do
        media = FactoryBot.create(:media)
        @cell.update!(picto: nil, media: media)
        expect(@cell.picto).to be_nil
        expect(@cell.media).to eq media
      end
    end
  end

  describe 'linkable_boards' do
    before :each do
      @unowned_board_set = FactoryBot.create :board_set
      @unowned_board = FactoryBot.create :board, board_set: @unowned_board_set, name: 'Unowned Board'

      @board_set = FactoryBot.create :board_set

      @unlinked_board = FactoryBot.create :board, board_set: @board_set, name: 'Unlinked Board'

      @unrelated_grandfather_board = FactoryBot.create :board, board_set: @board_set, name: 'Unrelated Grandfather Board'
      @unrelated_father_board = FactoryBot.create :board, board_set: @board_set, name: 'Unrelated Father Board'
      @unrelated_child_board = FactoryBot.create :board, board_set: @board_set, name: 'Unrelated Child Board'
      @unrelated_grandfather_board.cells.first.update!(linked_board: @unrelated_father_board)
      @unrelated_father_board.cells.first.update!(linked_board: @unrelated_child_board)

      # Check that we can walk down the tree to the child_board
      expect(@unrelated_grandfather_board.cells.first.linked_board.cells.first.linked_board).to eq @unrelated_child_board

      @grandfather_board = FactoryBot.create :board, board_set: @board_set, name: 'Grandfather Board'
      @father_board = FactoryBot.create :board, board_set: @board_set, name: 'Father Board'
      @child_board = FactoryBot.create :board, board_set: @board_set, name: 'Child Board'
      @grandfather_board.cells.first.update!(linked_board: @father_board)
      @father_board.cells.first.update!(linked_board: @child_board)

      # Check that we can walk down the tree to the child_board
      expect(@grandfather_board.cells.first.linked_board.cells.first.linked_board).to eq @child_board

      expect(@board_set.boards.count).to eq 7
    end
    it 'returns an array of Boards that can be linked to' do
      # The lowest descendent Board should not return itself, ancestors or already-linked-to Boards.
      expect(@child_board.cells.first.linkable_boards).to match_array [@unrelated_grandfather_board, @unlinked_board]

      # The middle Board should not return itself, ancestors or already-linked-to Boards.
      expect(@father_board.cells.first.linkable_boards).to match_array [@unrelated_grandfather_board, @unlinked_board]
    end
  end
end
