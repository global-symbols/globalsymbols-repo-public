class SvgToPngConversionJob < ApplicationJob
  queue_as :default

  # Preserve existing options and add locking
  sidekiq_options retry: 3, lock: :while_executing, lock_timeout: 0

  def perform(image_id)
    image = Image.find(image_id)
    return unless image.imagefile.file.extension.downcase == 'svg'

    image.update(status: 'converting')

    begin
      # Simulate a long-running conversion for testing (remove in production if not needed)
      sleep 10

      image.imagefile.cache!
      image.imagefile.svg2png
      image.imagefile.store!
      image.status = 'completed'
      image.save!
      Rails.logger.info "SvgToPngConversionJob completed for Image #{image_id}"
    rescue StandardError => e
      image.update(status: 'failed')
      Rails.logger.error "SvgToPngConversionJob failed for Image #{image_id}: #{e.message}"
      raise e  # Re-raise to trigger Sidekiq retries
    end
  end
end
