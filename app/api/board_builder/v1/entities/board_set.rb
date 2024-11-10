module BoardBuilder
  class V1::Entities::BoardSet < Grape::Entity
    expose :id,                documentation: { type: 'Integer', example: '123456', required: true }
    expose :name,              documentation: { type: 'String', example: 'My Board Set', required: true }
    expose :public,            documentation: { type: 'Boolean', example: 'false', required: true }
    expose :opened_at,         documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: false }
    expose :created_at,        documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: true }
    expose :updated_at,        documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: true }

    expose :boards, with: V1::Entities::Board, if: lambda { |board_set, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    } do |board_set|
      board_set.boards.order :index
    end

    # If options['readonly'] (bool) is specified, include it in the entity
    expose :readonly, if: lambda { |board, options| options[:readonly] != nil } do |board_set, options|
      options[:readonly]
    end

    expose :preview_cells, with: V1::Entities::Cell, if: lambda { |board_set, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    } do |board_set|
      # Return the first 5 cells that have an image_url set.
      # Ordered by Board ID, then cell index.
      board_set.cells.order(boardbuilder_board_id: :asc, index: :asc).where.not(image_url: nil).limit(5)
    end

    expose :owner, with: GlobalSymbols::V1::Entities::User, if: lambda { |board_set, options|
      options[:show_owner]
    } do |board_set|
      board_set.users.first
    end
  end
end