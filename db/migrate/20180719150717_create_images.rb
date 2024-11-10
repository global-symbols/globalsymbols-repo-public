class CreateImages < ActiveRecord::Migration[5.2]
  def change
    create_table :images do |t|
      t.references :picto, foreign_key: true, null: false
      t.string :filename
      t.string :uri

      t.timestamps
    end
  end
end
