class CreateSymbolsets < ActiveRecord::Migration[5.2]
  def change
    create_table :symbolsets do |t|
      t.string :name, null: false
      t.string :publisher, null: false
      t.string :publisher_url
      t.integer :status, null: false
      t.string :slug, null: false

      t.timestamps
    end
  end
end