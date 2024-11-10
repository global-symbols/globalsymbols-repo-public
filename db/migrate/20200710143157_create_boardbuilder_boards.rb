class CreateBoardbuilderBoards < ActiveRecord::Migration[6.0]
  def change
    create_table :boardbuilder_boards do |t|
      t.references :boardbuilder_board_set, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :index
      t.integer :columns, null: false
      t.integer :rows, null: false
      t.integer :captions_position, null: false

      t.timestamps
    end
  end
end
