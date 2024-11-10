class AddShowSymbolDescriptionAndLanguageToSurveys < ActiveRecord::Migration[5.2]
  def change
    add_column :surveys, :show_symbol_descriptions, :boolean, after: :close_at
    add_reference :surveys, :language, foreign_key: true, after: :previous_survey_id
  end
end
