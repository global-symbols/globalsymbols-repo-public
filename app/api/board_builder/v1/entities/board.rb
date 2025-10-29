module BoardBuilder
  class V1::Entities::Board < Grape::Entity
    expose :id,                 documentation: { type: 'Integer', example: '123456', required: true }
    expose :boardbuilder_board_set_id, as: :board_set_id,
                                documentation: { type: 'Integer', example: '123456', required: true }
    expose :header_boardbuilder_media_id, as: :header_media_id,
                                documentation: { type: 'Integer', example: '123456', required: false }
    expose :name,               documentation: { type: 'String', example: 'My Board', required: true }
    expose :description,        documentation: { type: 'String', example: 'This is a Board about...', required: false }
    expose :index,              documentation: { type: 'Integer', example: '5', required: true }
    expose :columns,            documentation: { type: 'Integer', example: '4', required: true }
    expose :rows,               documentation: { type: 'Integer', example: '3', required: true }
    expose :captions_position,  documentation: { type: 'String', example: 'below', required: true }
    expose :created_at,         documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: true }
    expose :updated_at,         documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: true }

    expose :cells, with: V1::Entities::Cell, if: lambda { |cells, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    } do |board|
      board.cells.sort_by{|e| e[:index]}
    end

    expose :board_set, with: V1::Entities::BoardSet, if: lambda { |board_set, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    } do |board|
      board.board_set
    end

    expose :header_media, with: V1::Entities::Media, if: lambda { |header_media, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    } do |board|
      board.header_media
    end
  end
end