module GlobalSymbols
  class V1::Entities::Label < Grape::Entity
    # Accepts expose_pictos_from_symbolset option, which limits exposed Pictos to the specified Symbolset.
    
    expose :id,               documentation: { type: 'Integer', example: 137531, required: true}
    expose :text,             documentation: { type: 'String', example: 'computer', required: true}
    expose :text_diacritised, documentation: { type: 'String', required: false, desc: 'Diacritised version of the text field for Arabic labels.'}
    expose :description,      documentation: { type: 'String', required: false}
    expose :language,         documentation: { type: 'String', example: 'eng', required: true} do |label|
      label.language.iso639_3
    end
    expose :picto, with: V1::Entities::Picto
  end
end