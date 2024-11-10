FactoryBot.define do
  factory :image do
    picto
    
    transient do
      file_format { 'png' }
    end
    
    after :build do |image, e|
      mime_map = {
          'png': 'image/png',
          'svg': 'image/svg+xml',
          'jpg': 'image/jpeg'
      }
      image.imagefile = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/picto.image.imagefile.#{e.file_format}"), mime_map[e.file_format.to_sym])
    end
  end
end
