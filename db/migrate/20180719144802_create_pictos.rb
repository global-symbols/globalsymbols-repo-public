class CreatePictos < ActiveRecord::Migration[5.2]
  def change
    create_table :pictos do |t|
      t.references :symbolset, foreign_key: true, null: false
      t.string :language, length:7
      t.integer :part_of_speech
      t.string :label
      t.string :undiacritised_label
      t.text :description

      t.timestamps
    end
  end
end
