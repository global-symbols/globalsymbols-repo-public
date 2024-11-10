class AddRoleToSurveyResponse < ActiveRecord::Migration[5.2]
  def change
    add_column :survey_responses, :role, :string, after: :organisation
  end
end
