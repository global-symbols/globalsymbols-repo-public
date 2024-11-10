class AddColoursToBoardbuilderCells < ActiveRecord::Migration[6.1]
  def change
    add_column :boardbuilder_cells, :hair_colour, :string, after: :text_colour
    add_column :boardbuilder_cells, :skin_colour, :string, after: :hair_colour
  end
end
