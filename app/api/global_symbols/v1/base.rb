module GlobalSymbols
  class V1::Base < Grape::API
    version 'v1', using: :path, vendor: 'globalsymbols'
    format :json
    
    # Helpers are available to mounted endpoints
    helpers do
      def current_user
      #   @current_user ||= User.authorize!(env)
      end
  
      def authenticate!
        error!({ error: "Unauthorized",
                 code: 401,
                 with: V1::Entities::Error},
               401) unless current_user
      end
    end
    
    # Automatically present 404s when ActiveRecord cannot find records.
    rescue_from ActiveRecord::RecordNotFound do |e|
      # Prepare the error message.
      message = "Couldn't find #{e.try(:model)}"
      # Append the ID lookup if one was used (e.g. for a Model.find(), but not a Model.find_by()).
      message = message + " with #{e.try(:primary_key)} #{e.try(:id)}" if e.primary_key.present?
      
      error!({ error: message,
               code: 404,
               with: V1::Entities::Error},
             404)
    end
    
    mount V1::Concepts
    mount V1::Labels
    mount V1::Languages
    mount V1::Symbolsets
    mount V1::User

    add_swagger_documentation \
      doc_version: version,
      info: {
        title: "Global Symbols API Version 1"
      }
  end
end