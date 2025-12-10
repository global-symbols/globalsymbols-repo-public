# frozen_string_literal: true

require 'faraday'
require 'digest'

# Custom error class for Directus API errors
class DirectusError < StandardError
  attr_reader :status_code, :response_body

  def initialize(message, status_code = nil, response_body = nil)
    super(message)
    @status_code = status_code
    @response_body = response_body
  end
end

# DirectusService is the single source of truth for all Directus API calls in this Rails application.
#
# This service handles authentication, caching, error handling, and logging for all interactions
# with the Directus API. It uses Faraday as the HTTP client and Rails.cache for aggressive caching.
#
# All requests include Bearer token authentication and JSON content-type headers.
# Responses are cached indefinitely by default, with configurable TTL.
#
# @example Basic usage
#   DirectusService.fetch_collection('articles')
#   DirectusService.fetch_item('articles', 123)
#   DirectusService.fetch_singleton('settings')
#
class DirectusService

  # Cache key namespace prefix
  CACHE_NAMESPACE = 'directus/'

  class << self
    # Fetches all items from a Directus collection.
    #
    # @param collection [String] The name of the Directus collection
    # @param params [Hash] Query parameters (e.g., { filter: { status: 'published' }, limit: 10 })
    # @param cache_ttl [ActiveSupport::Duration, nil] Cache TTL (default: nil for indefinite caching)
    # @return [Array<Hash>] Array of collection items
    # @raise [DirectusError] If the API request fails
    #
    # @example Fetch published articles with limit
    #   DirectusService.fetch_collection('articles', { filter: { status: 'published' }, limit: 5 })
    def fetch_collection(collection, params = {}, cache_ttl = nil)
      request(:get, "items/#{collection}", params, cache_ttl)['data']
    end

    # Fetches all items from a Directus collection with language-specific translation filtering.
    #
    # @param collection [String] The name of the Directus collection
    # @param language_code [String] Directus language code (e.g., 'en-GB', 'fr-FR')
    # @param params [Hash] Additional query parameters
    # @param cache_ttl [ActiveSupport::Duration, nil] Cache TTL (default: nil for indefinite caching)
    # @param notify_missing [Boolean] Whether to send email notifications for missing translations (default: true)
    # @param options [Hash] Additional options (force: true to bypass cache)
    # @return [Array<Hash>] Array of collection items with translations filtered by language
    # @raise [DirectusError] If the API request fails
    #
    # @example Fetch articles with French translations, fallback to English
    #   DirectusService.fetch_collection_with_translations('articles', 'fr-FR')
    def fetch_collection_with_translations(collection, language_code, params = {}, cache_ttl = nil, notify_missing = true, options = {})
      # Build query parameters for translation filtering
      translation_params = build_translation_params(language_code, params)

      # Force refresh cache if requested
      if options[:force] == true
        cache_key = build_cache_key(:get, "items/#{collection}", translation_params)
        Rails.cache.delete(cache_key)
      end

      items = fetch_collection(collection, translation_params, cache_ttl)

      # Skip filtering if requested (for showing all articles regardless of translations)
      if options[:skip_translation_filter] == true
        return items
      end

      # Filter items to only include those with translations in the requested language
      # or fallback to default language (en-GB)
      filtered_items = items.select do |item|
        translations = item['translations'] || []
        has_requested_language = translations.any? { |t| t['gs_languages_code'] == language_code }
        has_fallback_language = translations.any? { |t| t['gs_languages_code'] == DIRECTUS_DEFAULT_LANGUAGE }

        has_requested_language || has_fallback_language
      end

      # Handle missing translations
      missing_translations = items - filtered_items
      if missing_translations.any? && notify_missing
        handle_missing_translations(collection, missing_translations, language_code)
      end

      filtered_items
    end

    # Fetches a single item from a Directus collection with language-specific translation filtering.
    #
    # @param collection [String] The name of the Directus collection
    # @param id [String, Integer] The ID of the item to fetch
    # @param language_code [String] Directus language code (e.g., 'en-GB', 'fr-FR')
    # @param params [Hash] Additional query parameters
    # @param cache_ttl [ActiveSupport::Duration, nil] Cache TTL (default: nil for indefinite caching)
    # @param notify_missing [Boolean] Whether to send email notifications for missing translations (default: true)
    # @return [Hash] The item data with translation filtering applied
    # @raise [DirectusError] If the API request fails or item is not found
    #
    # @example Fetch article with French translation, fallback to English
    #   DirectusService.fetch_item_with_translations('articles', 123, 'fr-FR')
    def fetch_item_with_translations(collection, id, language_code, params = {}, cache_ttl = nil, notify_missing = true)
      # Build query parameters for translation filtering
      translation_params = build_translation_params(language_code, params)

      item = fetch_item(collection, id, translation_params, cache_ttl)

      # Check if item has the requested language translation
      translations = item['translations'] || []
      requested_translation = translations.find { |t| t['gs_languages_code'] == language_code }
      fallback_translation = translations.find { |t| t['gs_languages_code'] == DIRECTUS_DEFAULT_LANGUAGE }
      # Always try English as final fallback, even if default language is different
      english_translation = translations.find { |t| t['gs_languages_code'] == 'en-GB' }

      if requested_translation.nil? && fallback_translation.nil? && english_translation.nil?
        Rails.logger.warn("Item #{collection}/#{id} has no translations in #{language_code}, #{DIRECTUS_DEFAULT_LANGUAGE}, or en-GB")
        return nil
      end

      # Send notification if using fallback translation
      if requested_translation.nil? && fallback_translation.present? && notify_missing
        notify_missing_translation(collection, id, language_code, item_title: extract_item_title(item))
      end

      # Return item with translation information
      item.merge('requested_language' => language_code,
                 'has_requested_translation' => requested_translation.present?,
                 'has_fallback_translation' => fallback_translation.present?)
    end

    # Fetches a single item from a Directus collection by ID.
    #
    # @param collection [String] The name of the Directus collection
    # @param id [String, Integer] The ID of the item to fetch
    # @param params [Hash] Query parameters (e.g., { fields: 'title,content' })
    # @param cache_ttl [ActiveSupport::Duration, nil] Cache TTL (default: nil for indefinite caching)
    # @return [Hash] The item data
    # @raise [DirectusError] If the API request fails or item is not found
    #
    # @example Fetch article with specific fields
    #   DirectusService.fetch_item('articles', 123, { fields: 'title,content,author' })
    def fetch_item(collection, id, params = {}, cache_ttl = nil)
      request(:get, "items/#{collection}/#{id}", params, cache_ttl)['data']
    end

    # Fetches a singleton collection from Directus.
    #
    # @param collection [String] The name of the singleton collection
    # @param params [Hash] Query parameters
    # @param cache_ttl [ActiveSupport::Duration, nil] Cache TTL (default: nil for indefinite caching)
    # @return [Hash] The singleton data
    # @raise [DirectusError] If the API request fails
    #
    # @example Fetch site settings
    #   DirectusService.fetch_singleton('settings')
    def fetch_singleton(collection, params = {}, cache_ttl = nil)
      request(:get, "items/#{collection}", params, cache_ttl)['data']
    end

    # Makes a raw GET request to any Directus API endpoint.
    #
    # @param path [String] The API endpoint path (without leading slash)
    # @param params [Hash] Query parameters
    # @param cache_ttl [ActiveSupport::Duration, nil] Cache TTL (default: nil for indefinite caching)
    # @return [Hash] The full JSON response
    # @raise [DirectusError] If the API request fails
    #
    # @example Raw request to custom endpoint
    #   DirectusService.raw_get('users/me')
    def raw_get(path, params = {}, cache_ttl = nil)
      request(:get, path, params, cache_ttl)
    end

    # Clears all cached Directus API responses.
    #
    # This method deletes all cache keys that start with "directus/".
    # Useful for webhook handlers that need to invalidate cached data.
    #
    # @return [void]
    def clear_cache!
      Rails.cache.delete_matched("#{CACHE_NAMESPACE}*")
    end

    # Invalidates cached data for a specific collection.
    #
    # This method deletes all cache keys that match the collection pattern.
    # Useful for webhook handlers that need to invalidate specific collection data.
    #
    # @param collection [String] The name of the Directus collection to invalidate
    # @return [void]
    def invalidate_collection!(collection)
      Rails.logger.info("Cache invalidation: clearing Directus cache for collection '#{collection}'")
      Rails.cache.delete_matched("#{CACHE_NAMESPACE}#{collection}:*")
      Rails.logger.info("Cache invalidation completed for collection '#{collection}'")
      true
    end

    # Tests the connection to Directus API without caching.
    #
    # @return [Hash] Connection test results
    def test_connection
      begin
        response = faraday_connection.get do |req|
          req.url 'server/info'
        end
        {
          success: response.success?,
          status: response.status,
          url: "#{DIRECTUS_URL}/server/info",
          error: response.success? ? nil : "#{response.status} #{response.reason_phrase}"
        }
      rescue => e
        {
          success: false,
          status: nil,
          url: "#{DIRECTUS_URL}/server/info",
          error: e.message
        }
      end
    end

    # Tests access to the articles collection specifically
    #
    # @return [Hash] Articles collection access test results
    def test_articles_access
      begin
        # Test basic articles access with minimal fields
        response = faraday_connection.get do |req|
          req.url 'items/articles'
          req.params['fields'] = 'id,status'
          req.params['limit'] = 1
        end
        {
          success: response.success?,
          status: response.status,
          url: "#{DIRECTUS_URL}/items/articles",
          error: response.success? ? nil : "#{response.status} #{response.reason_phrase}",
          response_body: response.success? ? JSON.parse(response.body) : response.body
        }
      rescue => e
        {
          success: false,
          status: nil,
          url: "#{DIRECTUS_URL}/items/articles",
          error: e.message
        }
      end
    end

    private

    def request(method, path, params = {}, cache_ttl = nil)
      cache_key = build_cache_key(method, path, params)

      Rails.cache.fetch(cache_key, expires_in: cache_ttl) do
        url = "#{DIRECTUS_URL}/#{path}"
        url = "#{url}?#{params.to_query}" if params.present?

        Rails.logger.info("Directus API Request: #{method.upcase} #{url}")

        begin
          response = faraday_connection.send(method) do |req|
            req.url path
            req.params.merge!(params) if params.present?
          end

      Rails.logger.info("Directus API Response: #{response.status}")
      handle_response(response)
        rescue Faraday::ConnectionFailed => e
          Rails.logger.error("Directus API Connection Failed: #{e.message}")
          Rails.logger.error("Directus URL: #{DIRECTUS_URL}")
          Rails.logger.error("Full error: #{e.backtrace.join("\n")}")
          raise DirectusError.new("Failed to connect to Directus API: #{e.message}")
        rescue => e
          Rails.logger.error("Directus API Error: #{e.message}")
          raise DirectusError.new("Directus API request failed: #{e.message}")
        end
      end
    end

    def faraday_connection
      @faraday_connection ||= Faraday.new(url: DIRECTUS_URL) do |faraday|
        faraday.headers['Authorization'] = "Bearer #{DIRECTUS_TOKEN_CMS}"
        faraday.headers['Content-Type'] = 'application/json'
        faraday.options.timeout = 30  # 30 second timeout
        faraday.options.open_timeout = 10  # 10 second open timeout
        faraday.adapter Faraday.default_adapter
      end
    end

    def handle_response(response)
      return parse_json(response.body) if response.success?

      error_message = "Directus API error: #{response.status} #{response.reason_phrase}"
      Rails.logger.error("Directus API Error Details: #{response.body}") if response.body.present?
      raise DirectusError.new(error_message, response.status, response.body)
    end

    def parse_json(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise DirectusError.new("Invalid JSON response from Directus API: #{e.message}")
    end

    def build_cache_key(method, path, params)
      # Create a stable cache key based on method, path, and sorted params
      # Include collection name for easier invalidation
      collection = extract_collection_from_path(path)
      key_components = [method.to_s.upcase, path]
      key_components << params.to_json if params.present?

      digest = Digest::SHA256.hexdigest(key_components.join('|'))
      cache_key = "#{CACHE_NAMESPACE}#{collection}:#{digest}"

      # Log cache key generation for debugging
      Rails.logger.debug("Generated cache key: #{cache_key} for #{method} #{path}")

      cache_key
    end

    def extract_collection_from_path(path)
      # Extract collection name from paths like "items/articles" or "items/articles/123"
      if path =~ %r{items/([^/]+)}
        $1
      else
        'unknown'
      end
    end

    def build_translation_params(language_code, additional_params = {})
      # Base parameters for fetching translations - only request fields that exist and are permitted
      # categories is a M2M relationship, so we need categories.article_categories_id.name to get category names
      base_params = {
        fields: 'id,status,featured,slug,author.first_name,author.last_name,date_created,date_updated,image.filename_disk,image,categories.article_categories_id.name,categories.article_categories_id.id,translations.title,translations.content,translations.short_description,translations.gs_languages_code',
        filter: { status: { _eq: 'published' } }
      }

      # Merge with additional params
      base_params.deep_merge(additional_params)
    end

    def handle_missing_translations(collection, missing_items, language_code)
      Rails.logger.warn("Found #{missing_items.length} #{collection} items without #{language_code} or #{DIRECTUS_DEFAULT_LANGUAGE} translations")

      # Send batch notification for multiple missing translations
      if missing_items.length > 1
        batch_notify_missing_translations(collection, missing_items, language_code)
      else
        # Send individual notification for single missing translation
        item = missing_items.first
        notify_missing_translation(collection, item['id'], language_code, item_title: extract_item_title(item))
      end
    end

    def notify_missing_translation(collection, item_id, language_code, item_title: nil)
      Rails.logger.info("Sending email notification for missing #{language_code} translation in #{collection}/#{item_id}")

      begin
        TranslationNotificationMailer.missing_translation(
          collection: collection,
          item_id: item_id,
          requested_language: language_code,
          fallback_language: DIRECTUS_DEFAULT_LANGUAGE,
          item_title: item_title
        ).deliver_later
      rescue => e
        Rails.logger.error("Failed to send missing translation notification: #{e.message}")
      end
    end

    def batch_notify_missing_translations(collection, missing_items, language_code)
      Rails.logger.info("Sending batch email notification for #{missing_items.length} missing #{language_code} translations in #{collection}")

      missing_data = missing_items.map do |item|
        {
          collection: collection,
          item_id: item['id'],
          requested_language: language_code,
          fallback_language: DIRECTUS_DEFAULT_LANGUAGE,
          item_title: extract_item_title(item)
        }
      end

      begin
        TranslationNotificationMailer.batch_missing_translations(missing_data).deliver_later
      rescue => e
        Rails.logger.error("Failed to send batch missing translation notification: #{e.message}")
      end
    end

    def extract_item_title(item)
      # Try to find a title from the default language translation
      translations = item['translations'] || []
      default_translation = translations.find { |t| t['gs_languages_code'] == DIRECTUS_DEFAULT_LANGUAGE }
      default_translation&.dig('title') || item['title']
    end
  end
end
