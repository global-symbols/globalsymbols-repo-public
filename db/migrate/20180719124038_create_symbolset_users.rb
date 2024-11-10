class CreateSymbolsetUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :symbolset_users do |t|
      t.references :symbolset, foreign_key: true, null: false
      t.references :user, foreign_key: true, null: false
      t.integer :role, null: false

      t.timestamps
    end
  end
end
