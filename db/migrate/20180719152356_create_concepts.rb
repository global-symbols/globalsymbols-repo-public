class CreateConcepts < ActiveRecord::Migration[5.2]
  def change
    create_table :concepts do |t|
      t.references :coding_framework, foreign_key: true, null: false
      t.string :language, length: 7
      t.string :subject, null: false

      t.timestamps
    end
  end
end
