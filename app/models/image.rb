class Image < ApplicationRecord
  belongs_to :picto, inverse_of: :images

  # mount_uploader provides remote_imagefile_url; a special field that tells Carrierwave to get the "upload" from a URL
  # https://github.com/carrierwaveuploader/carrierwave#uploading-files-from-a-remote-location
  mount_uploader :imagefile, ImageUploader

  validates_presence_of :picto, :imagefile

  after_initialize :set_defaults, if: :new_record?
  before_save :set_adaptable, if: :imagefile_changed?

  private
    def set_defaults
      self.adaptable = false
    end

    def set_adaptable
      self.adaptable = self.imagefile.file.extension.downcase == 'svg' && self.imagefile.read.match?(/aac-(?:hair|skin)-fill/)
    end
end
