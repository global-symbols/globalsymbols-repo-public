class AddOrganisationToSurveyResponse < ActiveRecord::Migration[5.2]
  def change
    add_column :survey_responses, :organisation, :string, after: :name
  end
end
