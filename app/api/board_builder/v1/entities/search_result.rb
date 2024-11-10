module BoardBuilder
  class V1::Entities::SearchResult < Grape::Entity
    expose :id,            documentation: { type: 'String', example: '123456', required: true }
    expose :label,         documentation: { type: 'String', example: 'computer', required: true }
    expose :tooltip,       documentation: { type: 'String', example: 'computer in The Noun Project', required: true }
    expose :imageUrl,      documentation: { type: 'String', example: 'http://site.com/123456-computer.svg', required: true }
  end
end