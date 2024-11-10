class ApplicationController < ActionController::Base
  before_action :store_user_location!, if: :storable_location? # Must occur before any authenticate_user!
  before_action :authenticate_user!
  before_action :set_devise_permitted_params, if: :devise_controller?
  before_action :set_sentry_context
  before_action :set_locale

  after_action :allow_iframe
  
  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.json { head :forbidden }
      format.html {
        @alert = exception.message
        render 'errors/unauthorised', alert: exception.message, status: :unauthorized
      }
      format.all {
        head :forbidden
      }
    end
  end

  # Present a 404 page for NotFound and RoutingErrors
  rescue_from ActiveRecord::RecordNotFound, ActionController::RoutingError, ActionController::UnknownFormat do |exception|
    respond_to do |format|
      format.html { render 'errors/not_found', status: :not_found }
      format.all  { head :not_found }
    end
  end

  # See: https://github.com/doorkeeper-gem/doorkeeper/wiki/Running-Doorkeeper-with-Devise
  def current_resource_owner
    User.find(doorkeeper_token.resource_owner_id) if doorkeeper_token
  end
  
  protected
    
    # Allows additional parameters on Devise-related controllers.
    def set_devise_permitted_params
      # Allow additional user params on sign_up and account_update.
      allowed_keys = [:prename, :surname, :company, :language_id]
      devise_parameter_sanitizer.permit(:sign_up, keys: allowed_keys)
      devise_parameter_sanitizer.permit(:account_update, keys: allowed_keys)
    end
  
  private
    # Its important that the location is NOT stored if:
    # - The request method is not GET (non idempotent)
    # - The request is handled by a Devise controller such as Devise::SessionsController as that could cause an
    #    infinite redirect loop.
    # - The request is an Ajax request as this can lead to very unexpected behaviour.
    def storable_location?
      request.get? && is_navigational_format? && !devise_controller? && !request.xhr?
    end
    
    def store_user_location!
      # :user is the scope we are authenticating
      store_location_for(:user, request.fullpath)
    end
    
    # After sign in, redirect the user to the last page they were on, if it's been stored.
    def after_sign_in_path_for(resource_or_scope)
      stored_location_for(resource_or_scope) || super
    end

    # Defines data to be sent to Sentry along with stack traces, for debugging purposes
    def set_sentry_context
      # Sends current_user.id or nil if current_user is blank
      Sentry.set_user(id: current_user.try(:id))
      Sentry.set_extras(params: params.to_unsafe_h, url: request.url)
    end
    
    def set_locale
      begin
        I18n.locale = params[:locale] || I18n.default_locale
      rescue I18n::InvalidLocale
        # If an invalid locale was chosen, redirect to the current page with no locale set.
        redirect_to request.path
      end
    end
    
    # Append the locale to generated URLs.
    # This is a class method, to work around an issue with Devise
    # https://github.com/plataformatec/devise/wiki/How-To:--Redirect-with-locale-after-authentication-failure
    def self.default_url_options(options={})
      # logger.debug "default_url_options is passed options: #{options.inspect}\n"
      { locale: I18n.locale }.merge options
    end

    # Returns a Contentful Client
    # @param [Hash] params  Hash of Contentful parameters to override
    # @return [Contentful::Client]
    def contentful(params = {})
      options = {
        access_token: ENV['CONTENTFUL_ACCESS_TOKEN'],
        space: ENV['CONTENTFUL_SPACE_ID'],
        dynamic_entries: :auto,
        raise_errors: true,
        raise_for_empty_fields: false
      }.merge! params
      
      @client ||= Contentful::Client.new(options)
    end
  
    # Returns a Contentful Client that uses the Content Preview API
    # Used for previewing draft content
    # https://www.contentful.com/developers/docs/references/content-preview-api/
    def contentful_preview
      contentful({
        access_token: ENV['CONTENTFUL_PREVIEW_TOKEN'],
        api_url: 'preview.contentful.com'
      })
    end

    def allow_iframe
      response.headers.except! 'X-Frame-Options'
    end
end
