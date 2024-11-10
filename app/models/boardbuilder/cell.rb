class Boardbuilder::Cell < ApplicationRecord
  belongs_to :board, inverse_of: :cells, foreign_key: 'boardbuilder_board_id'
  belongs_to :linked_board, foreign_key: 'linked_to_boardbuilder_board_id', class_name: 'Boardbuilder::Board', required: false
  belongs_to :media, inverse_of: :cells, foreign_key: 'boardbuilder_media_id', required: false
  belongs_to :picto, inverse_of: :cells, required: false

  has_one_attached :image

  # generate_index must run before_save.
  # When creating a Board with Cells in nested_attributes, the Cells cannot see their neighbours any earlier in the lifecycle.
  before_save :generate_index, if: :new_record?

  validates :caption, length: { maximum: 250 }

  # Validate correct ancestry when a linked_board is set. Only on changes.
  validate :linked_board_is_in_board_set, if: [:linked_to_boardbuilder_board_id_changed?, :linked_board ]
  validate :linked_board_is_not_ancestor, if: [:linked_to_boardbuilder_board_id_changed?, :linked_board ]
  validate :linked_board_is_not_descendent, if: [:linked_to_boardbuilder_board_id_changed?, :linked_board ]

  validates :background_colour, format: { with: /\A#?(?:[A-F0-9]{3}){1,2}\z/i, message: "must be a hexadecimal colour code" }, allow_blank: true
  validates :border_colour,     format: { with: /\A#?(?:[A-F0-9]{3}){1,2}\z/i, message: "must be a hexadecimal colour code" }, allow_blank: true
  validates :text_colour,       format: { with: /\A#?(?:[A-F0-9]{3}){1,2}\z/i, message: "must be a hexadecimal colour code" }, allow_blank: true
  validates :hair_colour,       format: { with: /\A#?(?:[A-F0-9]{3}){1,2}\z/i, message: "must be a hexadecimal colour code" }, allow_blank: true
  validates :skin_colour,       format: { with: /\A#?(?:[A-F0-9]{3}){1,2}\z/i, message: "must be a hexadecimal colour code" }, allow_blank: true

  # Either media or picto can be specified, but not both.
  validates_absence_of :media, if: :picto
  validates_absence_of :picto, if: :media

  # Returns an array of Boards that can be linked to from this Cell
  def linkable_boards
    # Ancestors and descendents cannot be linked to
    disallowed_board_ids =
            board.ancestor_boards.pluck(:id) +
            board.descendent_boards.pluck(:id)

    # A Board cannot link to itself!
    disallowed_board_ids << board.id

    # A Board cannot link to any other linked-to Board in the set.
    disallowed_board_ids << board.board_set.cells.where.not(linked_to_boardbuilder_board_id: nil).pluck(:linked_to_boardbuilder_board_id).uniq

    board.board_set.boards.where.not(id: disallowed_board_ids.flatten.uniq)
  end
  
  def pdf_colours
    out = OpenStruct.new {}
    out.border     = hex_colour_without_hash(border_colour)     if border_colour.present?
    out.background = hex_colour_without_hash(background_colour) if background_colour.present?
    out.text       = hex_colour_without_hash(text_colour)       if text_colour.present?
    out
  end
  
  def has_adaptations?
    !!(hair_colour or skin_colour)
  end

  private

    def hex_colour_without_hash(colour)
      match = colour.match(/rgba?\((?<r>\d+),\s?(?<g>\d+),\s?(?<b>\d+)/)

      if match
        r, g, b = match.captures
        "#{r.to_i.to_s(16).rjust(2, "0")}#{g.to_i.to_s(16).rjust(2, "0")}#{b.to_i.to_s(16).rjust(2, "0")}"
      else
        colour.sub '#', ''
      end

    end

    def generate_index
      self.index = (self.board.cells.maximum(:index) || 0) + 1
    end

    def linked_board_is_in_board_set
      # Add a validation error when the linked_board is NOT in the same BoardSet.
      unless linked_board.in? board.board_set.boards.where.not(id: board.id)
        errors.add(:linked_board, 'must be another Board within this Cell\'s Board Set')
      end
    end

  def linked_board_is_not_ancestor
    # pp "Checking if #{linked_board.id} is in #{board.ancestor_boards.pluck(:id)}"
    if linked_board.id.in? board.ancestor_boards.pluck(:id)
      errors.add(:linked_board, 'cannot be a parent or ancestor of this Board')
    end
  end

  def linked_board_is_not_descendent
    # pp "Checking if #{linked_board.id} is in #{board.descendent_boards.pluck(:id)}"
    if linked_board.id.in? board.descendent_boards.pluck(:id)
      errors.add(:linked_board, 'cannot be a child of this Board')
    end
  end
  
  
end
