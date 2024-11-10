module BoardBuilder
  class V1::Entities::Media < Grape::Entity
    expose :id,         documentation: { type: 'Integer', example: '123456', required: true }

    expose :user_id,    documentation: { type: 'Integer', example: '123456', required: true }
    expose :format,     documentation: { type: 'String', example: 'svg', required: true }
    expose :filesize,   documentation: { type: 'Integer', example: '65000', required: true }
    expose :caption,    documentation: { type: 'String', example: '', required: true }
    expose :height,     documentation: { type: 'Integer', example: '300', required: true }
    expose :width,      documentation: { type: 'Integer', example: '300', required: true }

    expose :created_at, documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: true }
    expose :updated_at, documentation: { type: 'Date', example: '2020-07-08 14:23:28', required: true }


    expose :canvas_url, documentation: { type: 'String', example: 'https://s3.amazon.com/this/that/canvas.json', required: false } do |media|
      media.canvas.try(:url)
    end

    expose :public_url, documentation: { type: 'String', example: 'https://s3.amazon.com/this/that/image.png', required: true } do |media|
      media.file.url
    end

    expose :cells, with: V1::Entities::Cell, if: lambda { |board, options|
      options[:expand].try(:include?, options[:attr_path].join('.'))
    } do |media|
      media.cells
    end
  end
end