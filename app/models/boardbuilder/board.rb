class Boardbuilder::Board < ApplicationRecord
  belongs_to :board_set, inverse_of: :boards, foreign_key: 'boardbuilder_board_set_id'
  belongs_to :header_media, foreign_key: 'header_boardbuilder_media_id', required: false, class_name: 'Boardbuilder::Media'

  has_many :cells, inverse_of: :board, foreign_key: 'boardbuilder_board_id', dependent: :destroy
  has_many :linked_cells, inverse_of: :linked_board, foreign_key: 'linked_to_boardbuilder_board_id', class_name: 'Boardbuilder::Cell', dependent: :nullify

  has_many :pictos, through: :cells

  accepts_nested_attributes_for :cells

  validates :name, presence: true, length: { maximum: 250 }
  validates :description, length: { maximum: 250 }
  validates :columns, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 12 }
  validates :rows, presence: true, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 12 }
  validates :captions_position, presence: true

  enum captions_position: { hidden: 0, above: 1, below: 2, left: 3, right: 4 }

  after_initialize :set_defaults, if: :new_record?

  after_create :populate_cells
  after_update :populate_cells

  def ancestor_boards
    # Get the Boards linked to from Cells in this Board and walk UP the tree
    cells.where.not(linked_to_boardbuilder_board_id: nil).flat_map do |linked_cell|
      linked_cell.linked_board.ancestor_boards << linked_cell.linked_board
    end
  end

  def descendent_boards
    # Find Cells linking to this Board and walk DOWN the tree
    # Boardbuilder::Cell.where(linked_to_boardbuilder_board_id: this.board.id)
    x = Boardbuilder::Board.joins(:cells).where(board_set: board_set, boardbuilder_cells: { linked_to_boardbuilder_board_id: id })
    pp x

    x.flat_map do |descendent_board|
    # cells.where.not(linked_to_boardbuilder_board_id: nil).flat_map do |linked_cell|
      descendent_board.descendent_boards << descendent_board
    end
  end

  private
  def set_defaults
    self.captions_position ||= 'below'
  end

  def populate_cells
    required_cells = rows * columns

    # If we need more cells, create them.
    if cells.count < required_cells
      (required_cells - cells.count).times do |n|
        cells.create!
      end

    # If we have too many cells, destroy the un-needed ones starting from the end.
    elsif cells.count > required_cells
      cells.order(index: :desc).limit(cells.count - required_cells).destroy_all
    end
  end
end
