class CreateLabels < ActiveRecord::Migration[5.2]
  def change
    create_table :labels do |t|
      t.references :language, null: false, foreign_key: true
      t.references :picto, null: false, foreign_key: true
      t.string :text, null: false
      t.string :text_diacritised

      t.timestamps
    end
  end
end
