class Boardbuilder::CanvasUploader < CarrierWave::Uploader::Base
  # Include RMagick or MiniMagick support:
  # include CarrierWave::RMagick
  # include CarrierWave::MiniMagick

  # Choose what kind of storage to use for this uploader:
  # storage :file
  storage :aws

  configure do |config|
    config.aws_acl    = 'public-read'

    if Rails.env.production?
      config.aws_bucket  = 'gs-boardbuilder-userimages'     # required
      config.asset_host  = 'https://userassets.app.globalsymbols.com'
    else
      config.aws_bucket  = 'gs-boardbuilder-userimages-dev' # required
      config.asset_host  = 'https://d10e7zjo4flc3z.cloudfront.net'
    end

  end

  def asset_host
    Rails.env.production? ? 'https://userassets.app.globalsymbols.com' : 'https://d10e7zjo4flc3z.cloudfront.net'
  end

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    "#{Rails.env}/users/#{model.user.id}/#{model.class.to_s.underscore}/#{model.id}"
  end

  # Provide a default URL as a default if there hasn't been a file uploaded:
  # def default_url(*args)
  #   # For Rails 3.1+ asset pipeline compatibility:
  #   # ActionController::Base.helpers.asset_path("fallback/" + [version_name, "default.png"].compact.join('_'))
  #
  #   "/images/fallback/" + [version_name, "default.png"].compact.join('_')
  # end

  # Process files as they are uploaded:
  # process scale: [200, 300]
  #
  # def scale(width, height)
  #   # do something
  # end

  # Create different versions of your uploaded files:
  # version :thumb do
  #   process resize_to_fit: [50, 50]
  # end

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_allowlist
    %w[json]
  end

  def content_type_allowlist
    ['application/json']
  end

  # Override the filename of the uploaded files:
  # Avoid using model.id or version_name here, see uploader/store.rb for details.
  def filename
    "#{secure_token}.fabric.canvas.json" if original_filename.present?
  end

  protected

  def secure_token
    var = :"@#{mounted_as}_secure_token"
    model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.uuid)
  end
end
