module BoardBuilder
  class V1::Entities::BoardSet < Grape::Entity
    expose :id,                documentation: { type: 'Integer', example: '123456', required: true }
    expose :name,              documentation: { type: 'String', example: 'My Board Set', required: true }
    expose :public,            documentation: { type: 'Boolean', example: 'false', required: true }
    expose :opened_at,         documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: false }
    expose :created_at,        documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: true }
    expose :updated_at,        documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: true }
    expose :download_count,    documentation: { type: 'Integer', example: '20' }
    expose :description,       documentation: { type: 'String', example: '20' }
    expose :tags,              documentation: { type: 'JSON', example: '["TAG1", "TAG2"]' }
    expose :lang,              documentation: { type: 'String', example: 'en' }
    expose :author,            documentation: { type: 'String', example: 'Joe Bloggs' }
    expose :author_url,        documentation: { type: 'String', example: '<website of author>' }
    expose :self_contained,    documentation: { type: 'Boolean', example: 'false' }

    expose :thumbnail_url do |board_set, _options|
      board_set.thumbnail&.file&.url
    end

    expose :boards, with: V1::Entities::Board, if: lambda { |board_set, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    } do |board_set|
      if !options[:boards_with_cells].blank?
        options[:boards_with_cells].sort_by{|e| e[:index]}
      else
        board_set.boards.order :index
      end
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