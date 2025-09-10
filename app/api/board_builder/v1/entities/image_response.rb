module BoardBuilder
  module V1
    module Entities
      class ImageResponse < Grape::Entity
        expose :image_url, documentation: { type: 'string', desc: 'SAS URL for generated image' }
      end
    end
  end
end