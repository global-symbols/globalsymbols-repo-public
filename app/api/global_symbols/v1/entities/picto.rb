module GlobalSymbols
  class V1::Entities::Picto < Grape::Entity
    expose :id,             documentation: { type: 'Integer', example: 17869, required: true}
    expose :symbolset_id,   documentation: { type: 'Integer', example: 17, required: true}
    expose :part_of_speech, documentation: { type: 'String', example: 'noun', required: true, values: ['noun', 'verb', 'adjective', 'adverb', 'pronoun', 'preposition', 'conjunction', 'interjection', 'article', 'modifier']}
    expose :image_url, documentation: { type: 'String', example: 'https://globalsymbols.com/symbolsets/arasaac/symbols/17869/download.png', required: true } do |picto, options|
      picto.images.first.imagefile.url
    end
    expose :native_format, documentation: { type: 'String', required: true, values: ['svg', 'png'], example: 'png'} do |picto, options|
      picto.images.last.imagefile.file.extension.downcase
    end
    expose :adaptable, documentation: { type: 'String'} do |picto, options|
      picto.images.last.adaptable
    end

    expose :symbolset, with: V1::Entities::Symbolset, if: lambda { |tile, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    }

  end
end