class Boardbuilder::MediaUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  process resize_to_fit: [512, 512], if: :not_svg?
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
      "#{Rails.env}/users/#{model.user.id}/#{model.class.to_s.underscore}/#{model.id}"
    else
      "public/uploads/#{Rails.env}/#{model.class.to_s.underscore}/#{model.id}"
    end
  end

  def extension_allowlist
    %w[jpg jpeg gif png svg]
  end

  def content_type_allowlist
    [/image\/svg\+xml/, 'image/jpeg', 'image/png', 'image/gif']
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

  def store_dimensions
    if file && model
      model.width, model.height = ::MiniMagick::Image.open(file.file)[:dimensions]
    end
  end

  def not_svg?(file)
    file.content_type != 'image/svg+xml'
  end
end
