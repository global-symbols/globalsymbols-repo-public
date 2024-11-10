require 'doorkeeper/grape/helpers'

module BoardBuilder
  class V1::Base < Grape::API
    prefix 'boardbuilder'
    version 'v1', using: :path, vendor: 'boardbuilder'
    format :json
    use ::WineBouncer::OAuth2

    helpers Doorkeeper::Grape::Helpers
    
    # Automatically present 404s when ActiveRecord cannot find records.
    rescue_from ActiveRecord::RecordNotFound do |e|
      # Prepare the error message.
      message = "Couldn't find #{e.try(:model)}"
      # Append the ID lookup if one was used (e.g. for a Model.find(), but not a Model.find_by()).
      message = message + " with #{e.try(:primary_key)} #{e.try(:id)}" if e.primary_key.present?
      
      error!({ error: message,
               code: 404,
               with: GlobalSymbols::V1::Entities::Error},
             404)
    end

    # OAuthUnauthorizedError is raised when no Access Token is presented.
    rescue_from WineBouncer::Errors::OAuthUnauthorizedError do |e|
      error! e.response, 401
    end

    # OAuthForbiddenError is raised when a user is authenticated, but they lack the required scope.
    rescue_from WineBouncer::Errors::OAuthForbiddenError do |e|
      error! e.response, 403
    end

    # CanCan::AccessDenied is raised when the current_user isn't allowed to perform an action on an object.
    rescue_from ::CanCan::AccessDenied do |e|
      error! 'Access Denied', 403
    end

    # Convert RecordInvalid errors to an appropriate status code.
    rescue_from ActiveRecord::RecordInvalid do |e|
      error!({
                 message: "Couldn't save #{e.try(:model)}. #{e.message}",
                 errors: e.record.errors,
                 # with: V1::Entities::Error
             }, 400)
    end
    
    mount BoardBuilder::V1::BoardSets
    mount BoardBuilder::V1::Boards
    mount BoardBuilder::V1::Cells
    mount BoardBuilder::V1::Media
    mount BoardBuilder::V1::Search
    mount BoardBuilder::V1::Templates

    add_swagger_documentation \
      doc_version: version,
      info: {
          title: "BoardBuilder API Version 1"
      },
      endpoint_auth_wrapper: WineBouncer::OAuth2, # This is the middleware for securing the Swagger UI
      # swagger_endpoint_guard: 'oauth2',     # this is the guard method and scope
      token_owner: 'resource_owner',               # This is the method returning the owner of the token

      security_definitions: {
          oauth: {
              type: :oauth2,
              in: 'header',
              authorizationUrl: Rails.application.routes.url_helpers.oauth_authorization_url(host: 'localhost', port: 3000),
              tokenUrl: Rails.application.routes.url_helpers.oauth_token_url(host: 'localhost', port: 3000),
              flow: :implicit,
              scopes: {
                  'boardset:read': 'Read your Board Sets',
                  'boardset:write':  'Write to your Board Sets'
              }
          }
      },
      security: {
          gs_oauth: ['boardset:read', 'boardset:write']
      }
  end
end
