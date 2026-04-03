module GlobalSymbols
  class V1::Entities::PictoSummary < Grape::Entity
    expose :id,             documentation: { type: 'Integer', example: 17869, required: true}
    expose :part_of_speech, documentation: { type: 'String', example: 'noun', required: true, values: ['noun', 'verb', 'adjective', 'adverb', 'pronoun', 'preposition', 'conjunction', 'interjection', 'article', 'modifier']}
    expose :image_url, documentation: { type: 'String', example: 'https://globalsymbols.com/symbolsets/arasaac/symbols/17869/download.png', required: true } do |picto, options|
      picto.images.first.imagefile.url
    end
    expose :native_format, documentation: { type: 'String', required: true, values: ['svg', 'png'], example: 'png'} do |picto, options|
      picto.images.last.imagefile.file.extension.downcase
    end
    
    expose :labels, with: V1::Entities::LabelSummary, documentation: { type: 'Array', is_array: true, required: true, desc: 'Authoritative labels for this Picto in all available languages' } do |picto, options|
      # Filter to authoritative labels only
      authoritative_labels = picto.labels.select { |label| label.source&.authoritative? }
      
      # Return the labels array so Grape Entity can represent them properly
      authoritative_labels
    end
  end
end
