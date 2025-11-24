
# Ensure Directus configuration is loaded after env.rb in development
if Rails.env.development? && (DIRECTUS_URL.nil? || DIRECTUS_TOKEN_CMS.nil?)
  Rails.logger.info("Re-checking Directus configuration after env.rb load...")

  # Re-load Directus configuration in case env.rb set the variables
  directus_url        = ENV['DIRECTUS_URL']
  directus_token      = ENV['DIRECTUS_TOKEN_CMS']
  directus_webhook_secret = ENV['DIRECTUS_WEBHOOK_SECRET']

  if directus_url.present? && directus_token.present?
    # Set the constants now that we have the values
    Object.send(:remove_const, :DIRECTUS_URL) if defined?(DIRECTUS_URL)
    Object.send(:remove_const, :DIRECTUS_TOKEN_CMS) if defined?(DIRECTUS_TOKEN_CMS)
    Object.send(:remove_const, :DIRECTUS_WEBHOOK_SECRET) if defined?(DIRECTUS_WEBHOOK_SECRET)

    DIRECTUS_URL             = directus_url
    DIRECTUS_TOKEN_CMS       = directus_token
    DIRECTUS_WEBHOOK_SECRET  = directus_webhook_secret

    DIRECTUS_URL.freeze
    DIRECTUS_TOKEN_CMS.freeze
    DIRECTUS_WEBHOOK_SECRET.freeze

    Rails.logger.info("Directus configuration loaded successfully after env.rb")
  else
    Rails.logger.warn("Directus configuration still incomplete after env.rb load")
  end
end

# Dynamic language configuration from Directus - Live reloadable
Rails.logger.info("Setting up dynamic language configuration from Directus")

# Create a module to hold language configuration that can be updated live
module LanguageConfig
  class << self
    attr_accessor :available_locales, :language_mapping, :default_language
  end
end

# Initialize with minimal fallback
LanguageConfig.available_locales = [:en]
LanguageConfig.language_mapping = { en: 'en-GB' }.freeze
LanguageConfig.default_language = 'en-GB'.freeze

# Set initial Rails config
I18n.available_locales = LanguageConfig.available_locales

# Load language configuration synchronously in development
if Rails.env.development?
  begin
    Rails.logger.info("Loading language configuration from Directus in development...")
    LanguageConfigurationService.update_live_config
  rescue => e
    Rails.logger.error("Failed to load language configuration in development: #{e.message}")
    Rails.logger.warn("Using minimal fallback language configuration")
  end
else
  # Language configuration will be loaded on-demand or via deployment scripts in production
end

# Create global variables that can be updated live
$directus_language_mapping = LanguageConfig.language_mapping
$directus_default_language = LanguageConfig.default_language

# The LanguageConfig module has attr_accessor which creates the getter methods
# So LanguageConfig.language_mapping returns the instance variable set by update_live_config

# Define constants that reference the LanguageConfig methods
DIRECTUS_LANGUAGE_MAPPING = LanguageConfig.method(:language_mapping)
DIRECTUS_DEFAULT_LANGUAGE = LanguageConfig.method(:default_language)

Rails.application.configure do
  config.i18n.default_locale = :en

  # Allow translations to fall back to the default language, English.
  config.i18n.fallbacks = true
end
