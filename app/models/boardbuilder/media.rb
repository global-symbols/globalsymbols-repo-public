class Boardbuilder::Media < ApplicationRecord
  belongs_to :user, inverse_of: :boardbuilder_library_images, foreign_key: 'user_id'

  has_many :cells, inverse_of: :media, foreign_key: 'boardbuilder_media_id', dependent: :nullify

  has_many :boards_as_header, foreign_key: 'header_boardbuilder_media_id', class_name: 'Boardbuilder::Board', dependent: :nullify

  # file stores the actual image file that will be used in Boards, etc.
  # All media items have a file.
  mount_base64_uploader :file, Boardbuilder::MediaUploader

  # canvas stores the serialised FabricJS canvas JSON, for media items generated in Symbol Creator.
  # Only media items created in Symbol Creator have a canvas.
  mount_uploader :canvas, Boardbuilder::CanvasUploader

  validates_presence_of  :format
  validates_presence_of  :filesize
  validates_presence_of  :file

  validates :file, file_size: {
      maximum: 0.5.megabytes.to_i
  }

  validates :filesize, numericality: {
      less_than: 500000
  }

  before_validation :update_file_attributes
  after_initialize :calculate_and_set_file_hash

  attr_accessor :resize_width, :resize_height

  def initialize(attributes = {})
    @resize_width = attributes.delete(:resize_width)
    @resize_height = attributes.delete(:resize_height)
    super(attributes)
  end

  def calculate_and_set_file_hash
    return unless file.present? && file_hash.blank?

    begin
      content = file.read
      self.file_hash = Utils.calculate_hash(content)
    rescue StandardError => e
      Rails.logger.warn("could not calculate hash of media: #{e.message}")
      self.file_hash = nil
    end
  end

  private

  def update_file_attributes
    if file.present? && file_changed?
      self.format = file.file.content_type
      self.filesize = file.file.size
    end
    calculate_and_set_file_hash
  end
end
