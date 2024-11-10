class AddSurveyResponseToComments < ActiveRecord::Migration[5.2]
  def change
    add_reference :comments, :survey_response, foreign_key: true, false: true, after: :picto_id
  end
end
