FactoryBot.define do
  factory :media, class: Boardbuilder::Media do
    user

    transient do
      file_format { 'png' }
    end

    trait :with_canvas do
      after :build do |media, e|
        media.canvas = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/board_builder.media.canvas.json"), 'application/json')
      end
    end

    after :build do |media, e|
      mime_map = {
          'png': 'image/png',
          'svg': 'image/svg+xml',
          'jpg': 'image/jpeg'
      }
      media.file = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/picto.image.imagefile.#{e.file_format}"), mime_map[e.file_format.to_sym])
    end
  end
end
