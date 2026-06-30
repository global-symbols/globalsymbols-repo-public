require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module GlobalsymbolsRepo
  class Application < Rails::Application
    # Ruby 3.1+ disables YAML aliases by default; Rails 6.1 database.yml uses anchors.
    # Remove once on Rails 7.1+.
    ActiveSupport::ConfigurationFile.class_eval do
      def parse(context: nil, **options)
        YAML.load(render(context), aliases: true, **options) || {}
      rescue Psych::SyntaxError => error
        raise "YAML syntax error occurred while parsing #{@content_path}. " \
              "Please note that YAML must be consistently indented using spaces. Tabs are not allowed. " \
              "Error: #{error.message}"
      end
    end

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0

    config.allowed_image_extensions = %w[jpg jpeg gif png svg webp].freeze
    config.allowed_image_mimetypes = [/image\/svg\+xml/, 'image/jpeg', 'image/png', 'image/gif', 'image/webp'].freeze

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
