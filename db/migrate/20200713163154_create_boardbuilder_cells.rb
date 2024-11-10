class CreateBoardbuilderCells < ActiveRecord::Migration[6.0]
  def change
    create_table :boardbuilder_cells do |t|
      t.references :boardbuilder_board, null: false, foreign_key: true
      t.references :linked_to_boardbuilder_board, null: true, foreign_key: { to_table: :boardbuilder_boards }
      t.references :picto, null: true, foreign_key: true
      t.string :caption
      t.integer :index
      t.string :background_colour
      t.string :border_colour
      t.string :text_colour
      t.string :image_url

      t.timestamps
    end
  end
end
