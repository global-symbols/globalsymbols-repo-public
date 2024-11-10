module GlobalSymbols
  class V1::Entities::CodingFramework < Grape::Entity
    expose :id,        documentation: { type: 'Integer', example: 1, required: true}
    expose :name,      documentation: { type: 'String', example: 'ConceptNet', required: true}
    expose :structure, documentation: { type: 'String', example: 'linked_data', values: ['linked_data', 'legacy'], required: true}
  end
end