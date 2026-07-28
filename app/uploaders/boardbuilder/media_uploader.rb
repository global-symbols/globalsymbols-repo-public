class Boardbuilder::MediaUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  #process resize_to_fit: [512, 512], if: :not_svg?
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

  def store_dimensions
    return unless file && model

    path = file.file.to_s
    model.width, model.height = if svg_path?(path) || file.content_type == 'image/svg+xml'
                                  # Debian ImageMagick's internal SVG coder fails on Designer SVGs that
                                  # embed PNGs as data URIs; rsvg-convert handles those correctly.
                                  dimensions_via_rsvg(path)
                                else
                                  MiniMagick::Image.open(path)[:dimensions]
                                end
  rescue MiniMagick::Invalid, MiniMagick::Error => e
    Rails.logger.warn("[Boardbuilder::MediaUploader] store_dimensions failed for #{path}: #{e.message}")
  end

  private

  def svg_path?(path)
    path.to_s.downcase.end_with?('.svg', '.svgz')
  end

  def dimensions_via_rsvg(path)
    return unless system('which', 'rsvg-convert', out: File::NULL, err: File::NULL)

    Tempfile.create(['bb_media_dims', '.png']) do |tmp|
      tmp.close
      ok = system('rsvg-convert', '-o', tmp.path, path, out: File::NULL, err: File::NULL)
      return nil unless ok && File.size?(tmp.path)

      return MiniMagick::Image.open(tmp.path)[:dimensions]
    end
  end

  def not_svg?(file)
    file.content_type != 'image/svg+xml'
  end

  def resize
    width = model.resize_width || 512
    height = model.resize_height || 512
    resize_to_limit(width, height, combine_options: {"define" => 'png:exclude-chunk="*"'})
  end
end
