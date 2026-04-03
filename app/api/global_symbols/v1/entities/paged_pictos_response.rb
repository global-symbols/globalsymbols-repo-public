module GlobalSymbols
  class V1::Entities::PagedPictosResponse < Grape::Entity
    expose :items, with: V1::Entities::PictoSummary, documentation: { type: Array, is_array: true, required: true, desc: 'Array of PictoSummary objects' }
    expose :total, documentation: { type: 'Integer', example: 42, required: true, desc: 'Total number of Pictos matching the query, before pagination' }
    expose :deletions, documentation: { type: 'Array', is_array: true, required: false, desc: 'IDs of pictos that were deleted or archived since the "since" timestamp; present in delta responses (when since is used), may be empty' }
    expose :last_updated, documentation: { type: 'String', example: '2026-03-16T12:00:00Z', required: false, desc: 'ISO 8601 timestamp of the most recent change in the symbolset; included for delta responses' }
  end
end
