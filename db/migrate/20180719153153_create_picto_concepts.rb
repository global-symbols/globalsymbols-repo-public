class CreatePictoConcepts < ActiveRecord::Migration[5.2]
  def change
    create_table :picto_concepts do |t|
      t.references :concept, foreign_key: true
      t.references :picto, foreign_key: true

      t.timestamps
    end
  end
end
