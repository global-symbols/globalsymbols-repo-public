class CreateSurveyPictos < ActiveRecord::Migration[5.2]
  def change
    create_table :survey_pictos do |t|
      t.references :survey, foreign_key: true, null: false
      t.references :picto, foreign_key: true, null: false

      t.timestamps
    end
  end
end
