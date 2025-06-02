class ImageUploader < CarrierWave::Uploader::Base

  # define some uploader specific configurations in the initializer
  # to override the global configuration
  def initialize(*)
    super
    # config.asset_host = Rails.env.development? ? 'http://localhost:3000' : 'https://globalsymbols.com'
  end

  def asset_host
    ENV['ASSET_HOST'] || (Rails.env.development? ? 'http://localhost:3000' : 'https://globalsymbols.com')
  end

  # Include RMagick or MiniMagick support:
  # include CarrierWave::RMagick
  include CarrierWave::MiniMagick

  # Choose what kind of storage to use for this uploader:
  storage :file

  # Override the directory where uploaded files will be stored.
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    "uploads/#{Rails.env}/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def cache_dir
    "uploads/#{Rails.env}/tmp"
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

  version :svg2png, if: :svg? do
    def full_filename(for_file)
      'picto.png'
    end
    # For CarrierWave::RMagick
    # process background: 'none'
    # process alpha: 'Set'
    # process alpha: 'Activate'
    # process resize_to_fit: [500,500]
    # process convert: 'png'

    # process convert: 'png'
    # process resize_and_pad: [ 500, 500, :transparent ]

    # process :convert_to_png_rmagick

    # For CarrierWave::MiniMagick
    process :convert_to_png_minimagick

    def convert_to_png_rmagick
      manipulate! do |image, index, options|
        # options[:read] = {
        #   :background_color => 'none'
        # }
        options[:format] = 'png'
        image.resize_to_fit! 500
        # image.background_color! 'none'
        # image.convert 'png'
        image
      end
    end

    def convert_to_png_minimagick
      begin
        manipulate! do |image|

          # Due to an oversight in the design of MiniMagick, we have to inject parameters into the convert command manually.
          # To resize the SVG, we have to specify the canvas size BEFORE we load in the SVG. Else the resize happens post-rasterisation and we get a blurry result.
          # MiniMagick never foresaw this scenario, even though it's clearly documented in the man page for convert.
          # So, we have to use unshift to manually place the canvas parameters at the beginning of the convert command.
          # Yields something like:  convert -background none -resize 500x -density 500 input.svg output.png
          # Instead of:             convert input.svg -background none -resize 500x -density 500 output.png
          # Discussion: https://github.com/minimagick/minimagick/issues/332
          image.format("png") do |convert|

            # Parameters and values both have their own unshift, so everything is backwards.
            # Unshifting the parameter and the value together in one line fails for some reason.
            convert.args.unshift "500"
            convert.args.unshift "-density"

            convert.args.unshift "500x"
            convert.args.unshift "-resize"

            convert.args.unshift "none"
            convert.args.unshift "-background"

            pp convert.args

          end
          image
        end


        # minimagick! do |builder|
        #
        #   # Due to an oversight in the design of MiniMagick, we have to inject parameters into the convert command manually.
        #   # To resize the SVG, we have to specify the canvas size BEFORE we load in the SVG. Else the resize happens post-rasterisation and we get a blurry result.
        #   # MiniMagick never foresaw this scenario, even though it's clearly documented in the man page for convert.
        #   # So, we have to use unshift to manually place the canvas parameters at the beginning of the convert command.
        #   # Yields something like:  convert -background none -resize 500x -density 500 input.svg output.png
        #   # Instead of:             convert input.svg -background none -resize 500x -density 500 output.png
        #   # Discussion: https://github.com/minimagick/minimagick/issues/332
        #
        #   # Parameters and values both have their own unshift, so everything is backwards.
        #   # Unshifting the parameter and the value together in one line fails for some reason.
        #   builder#.limits(time: 10)
        #     .append('-density', 500)
        #     .append('-resize', '500x')
        #     .append('-background', 'none')
        # end

      rescue => e
        p 'PNG generation timed out.'
        p e
        raise
        nil
      end

    end
  end

  def content_type_allowlist
    [/image\//]
  end

  # Add a white list of extensions which are allowed to be uploaded.
  # For images you might use something like this:
  def extension_allowlist
    %w(jpg jpeg gif png svg)
  end

  # Override the filename of the uploaded files:
  # Avoid using model.id or version_name here, see uploader/store.rb for details.
  def filename
    "#{model.picto.symbolset.id}_#{model.picto.id}_#{secure_token}.#{file.extension}" if original_filename
  end

  protected
    def secure_token
      var = :"@#{mounted_as}_secure_token"
      model.instance_variable_get(var) or model.instance_variable_set(var, SecureRandom.uuid)
    end

    def svg?(new_file)
      new_file.extension.downcase == 'svg'
    end
end
