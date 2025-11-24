# frozen_string_literal: true

# Service for dynamically fetching language configuration from Directus
# Uses the languages collection with rails_code field for Rails locale mapping
class LanguageConfigurationService
  CACHE_KEY = 'directus/language_config'

  class << self
    def available_locales
      config['available_locales']
    end

    def directus_language_mapping
      config['directus_mapping']
    end

    def directus_default_language
      config['default_language']
    end

    def config
      # Check if Directus is configured before attempting to fetch
      unless ENV['DIRECTUS_URL'].present? && ENV['DIRECTUS_TOKEN_CMS'].present?
        Rails.logger.warn("Directus not configured, using default language configuration")
        return self.default_config
      end

      Rails.cache.fetch(CACHE_KEY) do
        self.fetch_from_directus
      end
    rescue => e
      Rails.logger.error("Failed to fetch language configuration: #{e.message}")
      self.default_config
    end

    def invalidate_cache!
      Rails.cache.delete(CACHE_KEY)
      # Also clear any Directus API caches that might be interfering
      Rails.cache.delete_matched("directus/*")
    end

    def refresh!
      invalidate_cache!
      config
    end

    def fetch_fresh_config
      # Force fresh data by clearing all cache and using cache_ttl=0 for Directus API
      Rails.cache.clear
      # Use a unique timestamp to ensure cache bypass
      languages = DirectusService.fetch_collection('languages', {}, 0)
      Rails.logger.info("Fetched #{languages.size} languages from Directus (cache completely bypassed)")

      # Build available locales from rails_code field
      available_locales = languages.map { |lang| lang['rails_code'].to_sym if lang['rails_code'].present? }.compact

      # Build mapping from rails_code to Directus code
      directus_mapping = {}
      languages.each do |lang|
        if lang['rails_code'].present? && lang['code'].present?
          directus_mapping[lang['rails_code'].to_sym] = lang['code']
        end
      end

      # Find default language
      default_language = languages.find { |lang| lang['default'] == true }&.dig('code') ||
                        languages.first&.dig('code') ||
                        'en-GB'

      Rails.logger.info("Fresh language config: #{available_locales.size} locales available")

      {
        'available_locales' => available_locales,
        'directus_mapping' => directus_mapping,
        'default_language' => default_language
      }
    end
  end

  def self.update_live_config
    begin
      Rails.logger.info("Updating live language configuration from Directus...")

      # Check if Directus is configured
      unless ENV['DIRECTUS_URL'].present? && ENV['DIRECTUS_TOKEN_CMS'].present?
        Rails.logger.warn("Directus not configured, cannot update live language configuration")
        return false
      end

      # Invalidate cache and get fresh config by bypassing all caching
      invalidate_cache!
      language_config = fetch_fresh_config

      Rails.logger.info("DEBUG: language_config = #{language_config.inspect}")

      # Update LanguageConfig module if available
      if defined?(LanguageConfig)
        Rails.logger.info("DEBUG: Updating LanguageConfig module")
        LanguageConfig.available_locales = language_config['available_locales']
        LanguageConfig.language_mapping = language_config['directus_mapping'].freeze
        LanguageConfig.default_language = language_config['default_language'].freeze
        Rails.logger.info("DEBUG: LanguageConfig updated - available_locales: #{LanguageConfig.available_locales.inspect}")
      else
        Rails.logger.warn("Language config: LanguageConfig module not defined!")
      end

        # Update Rails I18n
      if defined?(LanguageConfig)
        Rails.logger.info("DEBUG: Updating I18n.available_locales to: #{LanguageConfig.available_locales.inspect}")
        I18n.available_locales = LanguageConfig.available_locales
        Rails.logger.info("DEBUG: I18n.available_locales is now: #{I18n.available_locales.inspect}")
      else
        # Fallback
        I18n.available_locales = language_config['available_locales']
      end

      Rails.logger.info("Live language configuration updated: #{I18n.available_locales.inspect}")
      true
    rescue => e
      Rails.logger.error("Failed to update live language configuration: #{e.message}")
      Rails.logger.error("DEBUG: Exception backtrace: #{e.backtrace.first(5).join("\n")}")
      false
    end
  end

    private

  def self.default_config
    {
      'available_locales' => [:en],
      'directus_mapping' => { en: 'en-GB' },
      'default_language' => 'en-GB'
    }
  end

  def self.fetch_from_directus
    Rails.logger.info("Fetching language configuration from Directus")

    # Test Directus connectivity
    begin
      server_info = DirectusService.raw_get('server/info')
      Rails.logger.debug("Directus connectivity confirmed")
    rescue => e
      Rails.logger.error("Directus connectivity test failed: #{e.message}")
      raise e
    end

              # Fetch languages collection
              languages = DirectusService.fetch_collection('languages')
              Rails.logger.info("Fetched #{languages.size} languages from Directus")

    # Build available locales from rails_code field
    available_locales = languages.map { |lang| lang['rails_code'].to_sym if lang['rails_code'].present? }.compact

    # Build mapping from rails_code to Directus code
    directus_mapping = {}
    languages.each do |lang|
      if lang['rails_code'].present? && lang['code'].present?
        directus_mapping[lang['rails_code'].to_sym] = lang['code']
      end
      end

    # Find default language
    default_language = languages.find { |lang| lang['default'] == true }&.dig('code') ||
                        languages.first&.dig('code') ||
                        'en-GB'

    Rails.logger.info("Language config: #{available_locales.size} locales available")

      {
        'available_locales' => available_locales,
        'directus_mapping' => directus_mapping,
        'default_language' => default_language
      }
  rescue DirectusError => e
    Rails.logger.error("Failed to fetch language configuration from Directus: #{e.message}")
    default_config
  end
end