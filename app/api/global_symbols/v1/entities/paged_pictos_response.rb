module GlobalSymbols
  class V1::Entities::PagedPictosResponse < Grape::Entity
    expose :items, with: V1::Entities::PictoSummary, documentation: { type: Array, is_array: true, required: true, desc: 'Array of PictoSummary objects' }
    expose :total, documentation: { type: 'Integer', example: 42, required: true, desc: 'Total number of Pictos matching the query, before pagination' }
  end
end
