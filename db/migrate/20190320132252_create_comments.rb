class CreateComments < ActiveRecord::Migration[5.2]
  def change
    create_table :comments do |t|
      t.references :picto, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.integer :rating, null: false
      t.string :comment
      t.integer :likert1
      t.boolean :read
      t.boolean :resolved

      t.timestamps
    end
  end
end
