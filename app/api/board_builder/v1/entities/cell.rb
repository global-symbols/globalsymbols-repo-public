module BoardBuilder
  class V1::Entities::Cell < Grape::Entity
    expose :id,                 documentation: { type: 'Integer', example: '123456', required: true }
    expose :boardbuilder_board_id, as: :board_id,
                                documentation: { type: 'Integer', example: '333', required: true }
    expose :linked_to_boardbuilder_board_id, as: :linked_board_id,
                                documentation: { type: 'Integer', example: '334', required: true }
    expose :picto_id,           documentation: { type: 'Integer', example: '123', required: false }
    expose :adaptable,          documentation: { type: 'Boolean', example: true, required: false } do |cell|
      cell.picto ? cell.picto.images.last.adaptable : nil
    end
    expose :boardbuilder_media_id, as: :media_id,
                                documentation: { type: 'Integer', example: '123', required: false }
    expose :caption,            documentation: { type: 'String', example: 'Car', required: true }
    expose :background_colour,  documentation: { type: 'String', example: '#FFCC00', required: true }
    expose :border_colour,      documentation: { type: 'String', example: '#000000', required: true }
    expose :text_colour,        documentation: { type: 'String', example: '#000000', required: true }
    expose :hair_colour,        documentation: { type: 'String', example: '#000000', required: false }
    expose :skin_colour,        documentation: { type: 'String', example: '#000000', required: false }
    expose :image_url,          documentation: { type: 'String', example: 'https://site.com/car.png', required: true }
    expose :index,              documentation: { type: 'Integer', example: 'Position of the Cell within the Board', required: false }
    expose :created_at,         documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: true }
    expose :updated_at,         documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: true }

    expose :board, with: V1::Entities::Board, if: lambda { |board, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    } do |cell|
      cell.board
    end

    expose :picto, with: GlobalSymbols::V1::Entities::Picto, if: lambda { |board, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    } do |cell|
      cell.picto
    end

    expose :linkable_boards, with: V1::Entities::Board, if: lambda { |board, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    } do |cell|
      cell.linkable_boards
    end
  end
end