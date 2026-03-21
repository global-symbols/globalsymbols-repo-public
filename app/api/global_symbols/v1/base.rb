module GlobalSymbols
  class V1::Base < Grape::API
    version 'v1', using: :path, vendor: 'globalsymbols'
    format :json

    # Require valid API key for all v1 endpoints (except Swagger doc so /api/docs can load)
    before do
      next if env['PATH_INFO'].to_s.include?('swagger_doc')
      authenticate!
      current_api_key.touch(:last_used_at)
    end

    # Helpers are available to mounted endpoints
    helpers do
      def api_key_from_request
        auth = env['HTTP_AUTHORIZATION'].to_s.strip
        if auth.match(/\AApiKey\s+/i)
          auth.sub(/\AApiKey\s+/i, '').strip.presence
        elsif auth.present?
          # Accept raw key in Authorization (e.g. from Swagger UI when user pastes key only)
          auth.presence
        else
          env['HTTP_X_API_KEY'].to_s.strip.presence
        end
      end

      def current_api_key
        return @current_api_key if defined?(@current_api_key)
        raw = api_key_from_request
        @current_api_key = raw.present? ? APIKey.for_lookup(raw) : nil
      end

      def authenticate!
        unless current_api_key
          error!(
            { error: 'A valid, active API key is required. Provide it in the Authorization header as "ApiKey <key>" or in the X-Api-Key header.',
              code: 401,
              with: V1::Entities::Error },
            401
          )
        end
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
    mount V1::Pictos
    mount V1::User

    add_swagger_documentation \
      doc_version: version,
      info: {
        title: 'Global Symbols API Version 1',
        description: 'All endpoints require a valid, active API key. Send it in the Authorization header as "ApiKey <your_key>" or in the X-Api-Key header. Returns 401 if missing or invalid.'
      },
      security_definitions: {
        api_key: {
          type: :apiKey,
          in: :header,
          name: 'Authorization',
          description: 'API key. Example: "ApiKey your_key_here". Alternatively use header X-Api-Key.'
        }
      },
      security: [{ api_key: [] }]
  end
end