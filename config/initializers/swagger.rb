GrapeSwaggerRails.options.url      = '/api/v1/swagger_doc.json'

# Dynamically generate hostnames for example API requests.
GrapeSwaggerRails.options.before_action do
  GrapeSwaggerRails.options.app_url = request.protocol + request.host_with_port
end

GrapeSwaggerRails.options.app_name = 'Global Symbols'

GrapeSwaggerRails.options.doc_expansion = 'list'