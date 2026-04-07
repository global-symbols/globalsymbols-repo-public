module GlobalSymbols
  class V1::Base < Grape::API
    version 'v1', using: :path, vendor: 'globalsymbols'
    format :json

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
    mount V1::Pictos
    mount V1::User

    add_swagger_documentation \
      doc_version: version,
      info: {
        title: 'Global Symbols API Version 1',
        description: 'Public endpoints are available without an API key. Endpoints that use OAuth declare their own bearer-token requirements.'
      }
  end
end
