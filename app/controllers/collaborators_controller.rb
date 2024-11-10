class CollaboratorsController < ApplicationController
  
  load_and_authorize_resource :symbolset, find_by: :slug
  load_and_authorize_resource :collaborator, class: SymbolsetUser, except: :create
  
  def index
  end

  def create
    user = User.find_by(email: collaborator_params[:email])
    if user
      flash[:notice] = I18n.t('views.collaborators.create.notice_success', email_address: collaborator_params[:email]) if @symbolset.users << user
    else
      flash[:alert] = I18n.t('views.collaborators.create.alert_no_gs_account', email_address: collaborator_params[:email])
    end
    redirect_to symbolset_collaborators_path
  end

  def destroy
    # Ensure the current_user can't remove themself from the Symbol Set.
    if @collaborator.user != current_user
      flash[:notice] = I18n.t('views.collaborators.destroy.notice_success', email_address: @collaborator.user.email) if @collaborator.destroy
    end
    redirect_to symbolset_collaborators_path
  end
  
  private
  
    def collaborator_params
      params.permit(:email)
    end
end
