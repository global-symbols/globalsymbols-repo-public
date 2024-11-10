class ConceptsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]

  load_and_authorize_resource # Defines @concepts according to User Abilities
  
  def index
  end

  def show
    @pictos = @concept.pictos.accessible_by(current_ability).includes(:labels, :images)
  end
end
