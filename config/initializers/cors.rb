Rails.application.configure do
  # Allow CORS requests to API.
  config.middleware.insert_before 0, Rack::Cors do

    # Endpoints accessible from BoardBuilder
    allow do
      origins 'localhost:4200', 'localhost:9095', 'boardbuilder.globalsymbols.com', 'app.globalsymbols.com', 'app-dev.globalsymbols.com', 'gsboardbuilderdev.z33.web.core.windows.net', /global-symbols-boardbuilder-[\w-]+.web.app/, 'app-new.globalsymbols.com', 'grid.asterics.eu'

      # Allow CORS to required API methods
      resource '/api/*', headers: :any, methods: [:get, :post, :patch, :delete]

      # Allow CORS to the OAuth endpoints
      resource '/.well-known/*', headers: :any, methods: [:get]
      resource '/oauth/*', headers: :any, methods: [:get, :post]
    end


    # Endpoints accessible from anywhere
    allow do
      origins '*'

      # Allow CORS to the API
      resource '/api/v1/*', headers: :any, methods: [:get]

      # Allow CORS to the images
      resource '/uploads/*', headers: :any, methods: [:get]
      resource '/development/users/*', headers: :any, methods: [:get]
    end


  end
end