require 'doorkeeper/grape/helpers'

module GlobalSymbols
  class V1::User < Grape::API

    use ::WineBouncer::OAuth2
    helpers Doorkeeper::Grape::Helpers

    # OAuthUnauthorizedError is raised when no Access Token is presented.
    rescue_from WineBouncer::Errors::OAuthUnauthorizedError do |e|
      error! e.response, 401
    end

    # OAuthForbiddenError is raised when a user is authenticated, but they lack the required scope.
    rescue_from WineBouncer::Errors::OAuthForbiddenError do |e|
      error! e.response, 403
    end
    
    resource :user do
      desc 'Returns details of the authenticated User',
           success: V1::Entities::User,
           is_array: false
      oauth2 'profile'
      get do
        present resource_owner, with: V1::Entities::User
      end


      desc 'Updates the authenticated User',
           success: V1::Entities::User,
           is_array: false
      params do
        optional :default_hair_colour, type: String, desc: 'Colour in hex format'
        optional :default_skin_colour, type: String, desc: 'Colour in hex format'
      end
      oauth2 'profile'
      patch do
        resource_owner.update!(declared(params, include_missing: false))
        present resource_owner, with: V1::Entities::User
      end
    end
  end
end