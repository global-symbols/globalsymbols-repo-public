class AddNameToSurveyResponses < ActiveRecord::Migration[5.2]
  def change
    add_column :survey_responses, :name, :string, after: :user_id
  end
end
