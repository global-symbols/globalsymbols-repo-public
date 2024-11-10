class SurveysController < ApplicationController
  
  # Allow anonymous users to complete Surveys
  skip_before_action :authenticate_user!
  
  before_action :destroy_session_survey_response_id, on: [:show, :thank_you]

  load_and_authorize_resource :survey
  
  def show
    @response = SurveyResponse.new
  end
  
  def create_response
    # Create a new SurveyResponse and store it's ID in the session.
    @response = @survey.responses.create(response_params)
    session[:survey_response_id] = @response.id
    redirect_to survey_question_path(@survey, 1)
  end
  
  def thank_you
  end

  def print
    @example_symbol = Picto.new(part_of_speech: :noun, labels: [
        Label.new(language: Language.find_by(iso639_1: :en), text: 'Tree'),
        Label.new(language: Language.find_by(iso639_1: :fr), text: 'Arbre'),
        Label.new(language: Language.find_by(iso639_1: :hr), text: 'Drvo'),
        Label.new(language: Language.find_by(iso639_1: :sr), text: 'дрво'),
    ])
    
    @languages = Language.where(id: @survey.pictos.joins(:labels).pluck(:language_id).uniq)
  end
  
  private
  
  def response_params
    params.require(:survey_response).permit(:name, :organisation, :role)
  end
  
  def destroy_session_survey_response_id
    session.delete :survey_response_id
  end
end
