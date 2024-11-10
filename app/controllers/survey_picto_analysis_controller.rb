class SurveyPictoAnalysisController < ApplicationController
  
  load_and_authorize_resource :symbolset, find_by: :slug
  load_and_authorize_resource :survey, through: :symbolset
  
  def index
  end

  def show
    @picto = @survey.pictos.find(params[:id])
  end
end
