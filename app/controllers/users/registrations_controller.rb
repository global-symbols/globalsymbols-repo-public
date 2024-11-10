# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  prepend_before_action :authenticate_scope!, only: [:edit, :update, :destroy, :change_password, :update_password]
  prepend_before_action :set_minimum_password_length, only: [:new, :edit, :change_password, :update_password]

  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  def change_password
  end

  def update_password
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
    resource_updated = update_resource(resource, account_update_params)
    prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

    if resource_updated
      set_flash_message_for_update(resource, prev_unconfirmed_email)
      bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?

      respond_with resource, location: after_update_path_for(resource)
    else
      clean_up_passwords resource
      set_minimum_password_length
      render :'devise/registrations/change_password'
    end
  end

  def saved
    flash[:notice] = nil
  end

  # POST /resource
  # def create
  #   super
  # end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  # protected

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end
  
  # See https://github.com/doorkeeper-gem/doorkeeper/wiki/Running-Doorkeeper-with-Devise
  def authenticate_scope!
    # send(:"authenticate_#{resource_name}!", force: true)
    self.resource = send(:"current_#{resource_name}")
  end

  def after_update_path_for(resource)
    sign_in_after_change_password? ? users_saved_path : new_session_path(resource_name)

  end
end
