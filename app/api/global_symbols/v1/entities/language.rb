module GlobalSymbols
  class V1::Entities::Language < Grape::Entity
    expose :id,         documentation: { type: 'Integer', example: 1825, required: true}
    expose :name,       documentation: { type: 'String', example: 'English', required: true}
    expose :scope,      documentation: { type: 'String', example: 'I', required: true,
                                         values: ['I', 'M', 'S'],
                                         desc: 'https://iso639-3.sil.org/about/scope'}
    expose :category,   documentation: { type: 'String', example: 'L', required: true,
                                         values: ['L', 'E', 'C', 'A', 'H', 'S'],
                                         desc: 'https://iso639-3.sil.org/about/types'}
    expose :iso639_1,   documentation: { type: 'String', example: 'en', required: false}
    expose :iso639_2b,  documentation: { type: 'String', example: 'eng', required: false}
    expose :iso639_2t,  documentation: { type: 'String', example: 'eng', required: false}
    expose :iso639_3,   documentation: { type: 'String', example: 'eng', required: true}
  end
end