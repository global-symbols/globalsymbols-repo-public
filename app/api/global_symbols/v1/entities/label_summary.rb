module GlobalSymbols
  class V1::Entities::LabelSummary < Grape::Entity
    expose :language, documentation: { type: 'String', example: 'eng', required: true, desc: 'ISO639-3 language code' } do |label|
      label.language.iso639_3
    end
    expose :text, documentation: { type: 'String', example: 'computer', required: true, desc: 'Label text' }
    expose :text_diacritised, documentation: { type: 'String', required: false, desc: 'Diacritised version of the text field for Arabic labels.' } do |label|
      label.text_diacritised.presence
    end
  end
end
