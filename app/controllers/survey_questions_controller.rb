class SurveyQuestionsController < ApplicationController
  
  # Allow anonymous users to complete Surveys
  skip_before_action :authenticate_user!
  
  before_action :require_survey_to_be_open
  before_action :load_survey_response
  
  load_and_authorize_resource :survey
  
  def show
    @question = params[:id].to_i
    survey_picto = @survey.survey_pictos.limit(@question).offset(@question - 1).first
    @picto = survey_picto.picto
    
    @feedback = @survey_response.comments.find_or_initialize_by(picto: @picto)
  end
  
  def update
    @question = params[:id].to_i
    survey_picto = @survey.survey_pictos.limit(@question).offset(@question - 1).first
    @picto = survey_picto.picto
    
    @feedback = @survey_response.comments.find_or_initialize_by(picto: @picto)

    # If the feedback was saved successfully, redirect...
    if @feedback.update(feedback_params)
      # To the survey overview, if this was the last question.
      return redirect_to thank_you_survey_path(@survey) if @question == @survey.pictos.count
      
      # Otherwise, to the next question.
      redirect_to survey_question_path(@survey, (@question + 1))
    end
  end
  
  private
    def feedback_params
      params.require(:comment).permit(:rating, :comment, :representation_rating, :contrast_rating, :cultural_rating)
    end
    
    # Redirects to the Survey show page if the survey isn't open for feedback
    def require_survey_to_be_open
      @survey = Survey.find(params[:survey_id])
      redirect_to survey_path(@survey) unless @survey.is_open_for_feedback?
    end
  
    def load_survey_response
      begin
        @survey_response = @survey.responses.find(session[:survey_response_id])
      rescue ActiveRecord::RecordNotFound
        # Redirect to the start of the survey if the response is not found
        # (e.g. expired page when user returns after a timeout)
        flash.alert = I18n.t('views.survey_questions._controller.timed_out')
        redirect_to survey_path(@survey)
      end
    end
end
