module GlobalSymbols
  class V1::Entities::Licence < Grape::Entity
    expose :name,        documentation: { type: 'String', example: 'Creative Commons BY NC SA 4.0', required: true}
    expose :url,         documentation: { type: 'String', example: 'https://creativecommons.org/licenses/by-nc-sa/4.0/', required: false}
    expose :version,     documentation: { type: 'String', example: '4.0', required: false}
    expose :properties,  documentation: { type: 'String', example: 'by-nc-sa', required: false}
  end
end