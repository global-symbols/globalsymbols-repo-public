class Boardbuilder::MediaUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick


  process :resize, if: :not_svg?
  process :store_dimensions

  # Set storage based on environment configuration
  storage Rails.application.config.uploader_storage || :file

  configure do |config|
    if Rails.application.config.uploader_storage == :aws
      config.aws_acl = 'public-read'
      config.aws_bucket = Rails.application.config.uploader_aws_bucket || 'gs-boardbuilder-userimages' # Fallback
      config.asset_host = Rails.application.config.uploader_asset_host || 'https://userassets.app.globalsymbols.com' # Fallback
    end
  end

  def asset_host
    if Rails.application.config.uploader_storage == :aws
      Rails.application.config.uploader_asset_host || 'https://userassets.app.globalsymbols.com'
    else
      # For local storage, use the Rails server URL
      ActionController::Base.asset_host || "http://#{Rails.application.config.action_mailer.default_url_options[:host]}:#{Rails.application.config.action_mailer.default_url_options[:port]}"
    end
  end

  def store_dir
    if Rails.application.config.uploader_storage == :aws
      "#{Rails.env}/users/#{model.user_id}/#{model.class.to_s.underscore}/#{model.id}"
    else
      "public/uploads/#{Rails.env}/#{model.class.to_s.underscore}/#{model.id}"
    end
  end

  def extension_allowlist
    Rails.application.config.allowed_image_extensions
  end

  def content_type_allowlist
    Rails.application.config.allowed_image_mimetypes
  end

  def filename
    "#{secure_token}.#{file.extension}" if original_filename.present?
  end

  protected

  def secure_token
    var = :"@#{mounted_as}_secure_token"
    model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.uuid)
  end

  private

  def not_svg?(file)
    file.content_type != 'image/svg+xml'
  end

  def resize
    width = model.resize_width || 512
    height = model.resize_height || 512
    resize_to_limit(width, height, combine_options: {"define" => 'png:exclude-chunk="*"'})
  end
end
