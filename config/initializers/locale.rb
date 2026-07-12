# frozen_string_literal: true

# Ensure Directus configuration is loaded after env.rb in development
if (Rails.env.development? || Rails.env.test?) && (DIRECTUS_URL.nil? || DIRECTUS_TOKEN_CMS.nil?)
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

# Dynamic language configuration from Directus - live reloadable.
# LanguageConfig + minimal fallback are set here (no app/services constants).
# Loading from cache/Directus is deferred to after_initialize so Zeitwerk can
# resolve LanguageConfigurationService (referencing it during the initializer
# phase caused: uninitialized constant LanguageConfigurationService).
Rails.logger.info("Setting up dynamic language configuration from Directus")

module LanguageConfig
  class << self
    attr_accessor :available_locales, :language_mapping, :default_language

    def apply_from_hash!(config_hash)
      self.available_locales = config_hash["available_locales"]
      self.language_mapping = config_hash["directus_mapping"].freeze
      self.default_language = config_hash["default_language"].freeze
      I18n.available_locales = available_locales
    end
  end
end

# Minimal fallback until after_initialize (or if Directus/cache is unavailable)
LanguageConfig.available_locales = [:en]
LanguageConfig.language_mapping = { en: "en-GB" }.freeze
LanguageConfig.default_language = "en-GB".freeze

I18n.available_locales = LanguageConfig.available_locales

# Live-updatable references (LanguageConfig is mutated by LanguageConfigurationService)
DIRECTUS_LANGUAGE_MAPPING = LanguageConfig.method(:language_mapping)
DIRECTUS_DEFAULT_LANGUAGE = LanguageConfig.method(:default_language)

Rails.application.configure do
  config.i18n.default_locale = :en
  config.i18n.fallbacks = true
end

Rails.application.config.after_initialize do
  # App constants (LanguageConfigurationService, DirectusService) are loadable here.
  begin
    if Rails.env.development?
      Rails.logger.info("Loading language configuration from Directus in development...")
      unless LanguageConfigurationService.update_live_config
        Rails.logger.warn("Using minimal fallback language configuration")
      end
    else
      # pre-prod / production / stage: prefer Redis cache, self-heal on miss
      cached_config = Rails.cache.read(LanguageConfigurationService::CACHE_KEY)
      if cached_config.present?
        Rails.logger.info("Loading language configuration from cache")
        LanguageConfig.apply_from_hash!(cached_config)
        Rails.logger.info("Language configuration loaded from cache: #{I18n.available_locales.inspect}")
      else
        Rails.logger.warn("No cached language configuration found, attempting Directus refresh")
        if LanguageConfigurationService.update_live_config
          Rails.logger.info("Language configuration refreshed during boot: #{I18n.available_locales.inspect}")
        else
          Rails.logger.warn("Language refresh during boot failed, using minimal fallback language configuration")
        end
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to load language configuration after initialize: #{e.class}: #{e.message}")
    Rails.logger.warn("Using minimal fallback language configuration")
  end
end
