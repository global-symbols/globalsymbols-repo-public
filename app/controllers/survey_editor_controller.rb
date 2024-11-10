class SurveyEditorController < ApplicationController
  
  load_and_authorize_resource :symbolset, find_by: :slug
  
  # Loads authorised surveys in @symbolset.surveys.
  # Using parent: false because the controller name is different to the model name
  # see https://github.com/CanCanCommunity/cancancan/wiki/authorizing-controller-actions#custom-class
  load_and_authorize_resource :survey, parent: false, through: :symbolset
  
  def index
  end
  
  def show
  end
  
  def new
  end

  def edit
  end

  def create
    redirect_to symbolset_survey_path(id: @survey.id) if @survey.save
  end

  def update
    redirect_to symbolset_survey_path if @survey.update(survey_params)
  end
  
  def destroy
    @survey.destroy
    flash[:notice] = I18n.t('views.survey_editor.destroy.notice', name: @survey.name)
    redirect_to symbolset_surveys_path
  end
  
  def add_symbol
    picto = Picto.find(params[:symbol_id])

    begin
      @survey.pictos << picto
      flash[:notice] = I18n.t('views.survey_editor.add_symbol.notice_success', add_another_link: view_context.link_to(I18n.t('views.survey_editor.add_symbol.notice_success_add_another'), symbolset_survey_path)).html_safe
    rescue ActiveRecord::RecordInvalid
      flash[:alert] = I18n.t('views.survey_editor.add_symbol.alert_failure', survey_link: view_context.link_to(@survey.name, symbolset_survey_path)).html_safe
    end

    redirect_back fallback_location: '/'
  end

  def remove_symbol
    @survey.survey_pictos.find(params[:survey_picto_id]).delete
    redirect_to symbolset_survey_path
  end
  
  def export
    @comments = Comment.joins(:survey_response).where(survey_responses: {survey_id: @survey.id}).order(:user_id, :picto_id)
    respond_to do |format|
      format.xlsx {
        response.headers['Content-Disposition'] = "attachment; filename=\"#{@survey.name.parameterize}.xlsx\""
      }
    end
  end

  private
  
    def survey_params
      params.require(:survey).permit(:name, :introduction, :previous_survey_id, :close_at, :status, :show_symbol_descriptions, :language_id)
    end
end
