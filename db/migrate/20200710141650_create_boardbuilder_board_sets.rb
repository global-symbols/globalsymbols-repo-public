class CreateBoardbuilderBoardSets < ActiveRecord::Migration[6.0]
  def change
    create_table :boardbuilder_board_sets do |t|
      t.string :name
      t.boolean :public

      t.timestamps
    end
  end
end
