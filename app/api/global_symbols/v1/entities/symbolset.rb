module GlobalSymbols
  class V1::Entities::Symbolset < Grape::Entity
    expose :id,             documentation: { type: 'Integer', example: 17, required: true}
    expose :slug,           documentation: { type: 'String', example: 'arasaac', required: true}
    expose :name,           documentation: { type: 'String', example: 'ARASAAC', required: true}
    expose :publisher,      documentation: { type: 'String', example: 'Government of Aragon', required: true}
    expose :publisher_url,  documentation: { type: 'String', example: 'http://www.arasaac.org/', required: true}
    expose :status,         documentation: { type: 'String', example: 'published', required: true, values: ['published', 'draft']}
    expose :licence,        documentation: { required: true }, with: V1::Entities::Licence
    expose :featured_level, documentation: { type: 'Integer', example: 1, required: false}
  end
end