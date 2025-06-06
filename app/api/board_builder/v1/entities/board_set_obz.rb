module BoardBuilder
  class V1::Entities::BoardSetObz < Grape::Entity

    require_relative '../../util/boards_to_obz'

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

    expose :obz_file_map do |board_set|
      boards = board_set.boards.sort_by{|e| e[:index]}
      BoardBuilder::Util::BoardsToObz.boards_to_obz_file_map(boards)
    end

    expose :owner do |board_set|
      user = board_set.users.first
      {
        "prename" => user.prename,
        "surname" => user.surname
      }
    end
  end
end