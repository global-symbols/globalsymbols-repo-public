class CreateSurveys < ActiveRecord::Migration[5.2]
  def change
    create_table :surveys do |t|
      t.references :symbolset, foreign_key: true, null: false
      t.bigint :previous_survey_id, index: true
      t.string :name, null: false
      t.text :introduction
      t.integer :status, null: false
      t.datetime :close_at

      t.timestamps
    end
    
    add_foreign_key :surveys, :surveys, column: :previous_survey_id
  end
end
