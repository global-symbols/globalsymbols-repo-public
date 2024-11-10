class CreateBoardbuilderBoardSetUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :boardbuilder_board_set_users do |t|
      t.references :boardbuilder_board_set, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :role, null: false

      t.timestamps
    end
  end
end
