module GlobalSymbols
  class V1::Entities::Concept < Grape::Entity
    # Accepts expose_pictos_from_symbolset option, which limits exposed Pictos to the specified Symbolset.
    
    expose :id,        documentation: { type: 'Integer', example: 25248, required: true}
    expose :subject,   documentation: { type: 'String', example: 'computer', required: true}
    expose :coding_framework, with: V1::Entities::CodingFramework, documentation: { required: true }
    expose :language, with: V1::Entities::Language, documentation: { required: true }
    expose :pictos_count, documentation: { type: 'Integer', example: 2, required: true} do |concept|
      concept.pictos.published.count
    end
    expose :pictos, documentation: { type: V1::Entities::Picto, required: true } do |concept, options|
      pictos = concept.pictos.published
      pictos = pictos.where(symbolset: options[:expose_pictos_from_symbolset]) if options[:expose_pictos_from_symbolset]
      V1::Entities::Picto.represent pictos
    end
    expose :api_uri, documentation: { type: 'String', example: 'http://api.conceptnet.io/c/en/computer', required: true}
    expose :www_uri, documentation: { type: 'String', example: 'http://www.conceptnet.io/c/en/computer', required: true}
  end
end