class CreateLanguages < ActiveRecord::Migration[5.2]
  def change
    create_table :languages do |t|
      t.references :language, foreign_key: true
      t.string :name, null: false, limit: 150
      t.string :scope, null: false, limit: 1
      t.string :category, null: false, limit: 1
      t.string :iso639_3, null: false, limit: 3
      t.string :iso639_2b, limit: 3
      t.string :iso639_2t, limit: 3
      t.string :iso639_1, limit: 2

      t.timestamps
      
      t.index :iso639_3, unique: true
    end
  end
end
