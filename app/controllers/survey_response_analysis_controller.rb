class SurveyResponseAnalysisController < ApplicationController
  
  load_and_authorize_resource :symbolset, find_by: :slug
  load_and_authorize_resource :survey, through: :symbolset
  load_and_authorize_resource :response, through: :survey, parent: false, class: SurveyResponse
  
  def index
    @responses = @survey.responses.joins(:user).order('users.email')
  end

  def show
    @response = @survey.responses.find(params[:id])
  end
  
  def new
    picto_ids = @survey.pictos.pluck(:id)
    @response.comments.build(picto_ids.map{ |p| {picto_id: p}})
  end
  
  def create
    @response.user = current_user
    if @response.save!
      flash.notice = I18n.t('views.survey_response_analysis.create.notice_success')
      redirect_to symbolset_survey_path id: @response.survey
    else
      render :new
    end
  end
  
  private
  
    def response_params
      params.require(:response).permit(comments_attributes: [:picto_id, :rating, :comment, :representation_rating, :contrast_rating, :cultural_rating])
    end
end
