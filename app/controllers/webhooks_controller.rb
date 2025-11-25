# frozen_string_literal: true

class WebhooksController < ApplicationController
  # Webhooks should not require authentication
  skip_before_action :authenticate_user!

  # Skip CSRF token verification for webhook endpoints (external API calls)
  skip_before_action :verify_authenticity_token, only: [:directus]

  # Collections that affect language configuration
  LANGUAGE_CONFIG_COLLECTIONS = %w[languages].freeze

  def update_live_language_config
    LanguageConfigurationService.update_live_config
  end

  # Development-only endpoint to simulate Directus webhooks
  # GET /webhooks/directus/simulate?collection=articles&locales=en-GB,fr-FR
  #
  # Parameters:
  # - collection: The collection name (default: 'articles')
  # - locales: Comma-separated list of language codes (default: 'en-GB,fr-FR')
  #
  # Example usage:
  # GET /webhooks/directus/simulate?collection=articles&locales=en-GB,de-DE
  # This will simulate updating an article with English and German translations,
  # invalidate the articles cache, and warm only those two locales.
  def simulate
    # Only allow in development
    unless Rails.env.development?
      render json: { error: 'Simulation endpoint only available in development' }, status: :not_found
      return
    end

    collection = params[:collection] || 'articles'
    locales_param = params[:locales] || 'en-GB,fr-FR'
    locales = locales_param.split(',').map(&:strip)

    # Debug logging
    Rails.logger.info("Webhook simulate params: collection=#{collection}, locales_param=#{locales_param}")
    Rails.logger.info("Full params: #{params.inspect}")

    # Construct a realistic Directus webhook payload (always use 'update' action)
    payload = build_simulated_payload(collection, 'update', locales)

    # Simulate webhook processing directly
    simulation_result = simulate_webhook_processing(payload)

    render json: {
      status: 'simulated',
      collection: collection,
      locales: locales,
      payload: payload,
      processing_result: simulation_result,
      message: 'Webhook simulation completed'
    }
  end

  def directus
    start_time = Time.current
    Rails.logger.info("=== DIRECTUS WEBHOOK RECEIVED ===")
    Rails.logger.info("Timestamp: #{start_time}")
    Rails.logger.info("CSRF verification skipped for webhook endpoint")
    Rails.logger.info("Headers: #{request.headers.to_h.select { |k,v| k.start_with?('HTTP_') || ['CONTENT_TYPE', 'CONTENT_LENGTH'].include?(k) }.inspect}")
    Rails.logger.info("Method: #{request.method}")
    Rails.logger.info("URL: #{request.url}")
    Rails.logger.info("Remote IP: #{request.remote_ip}")
    Rails.logger.info("User Agent: #{request.user_agent}")
    Rails.logger.info("Content-Type: #{request.content_type}")
    Rails.logger.info("Content-Length: #{request.content_length}")

    # Verify webhook secret from Authorization header
    auth_header = request.headers['Authorization']
    Rails.logger.info("Authorization header present: #{auth_header.present?}")
    unless auth_header == "Bearer #{DIRECTUS_WEBHOOK_SECRET}"
      Rails.logger.warn("❌ Directus webhook received with invalid authorization. Expected: Bearer #{DIRECTUS_WEBHOOK_SECRET}, Got: #{auth_header}")
      Rails.logger.warn("📤 Response: 401 Unauthorized")
      Rails.logger.warn("=== DIRECTUS WEBHOOK FAILED ===")
      head :unauthorized
      return
    end
    Rails.logger.info("✅ Authorization successful")

    # Parse JSON payload
    raw_body = request.body.read
    Rails.logger.info("Raw request body: #{raw_body}")
    Rails.logger.info("Raw body length: #{raw_body.length} characters")

    begin
      payload = JSON.parse(raw_body)
      Rails.logger.info("=== PARSED PAYLOAD STRUCTURE ===")
      Rails.logger.info("Full payload: #{payload.inspect}")
      Rails.logger.info("Payload keys: #{payload.keys.inspect}")
      Rails.logger.info("Payload class types:")
      payload.each do |key, value|
        Rails.logger.info("  #{key}: #{value.class} - #{value.inspect}")
      end

      # Check if this looks like a Directus Flow payload
      if payload.key?('data') && payload['data'].to_s.include?('trigger.payload')
        Rails.logger.warn("⚠️  Detected Directus Flow payload with malformed template: #{payload['data']}")
        Rails.logger.warn("This suggests the HTTP Request operation in your Directus Flow is using incorrect template syntax")
      end

    rescue JSON::ParserError => e
      Rails.logger.error("❌ Directus webhook received invalid JSON: #{e.message}")
      Rails.logger.error("Raw body that failed to parse: #{raw_body}")
      Rails.logger.error("📤 Response: 400 Bad Request")
      Rails.logger.error("=== DIRECTUS WEBHOOK FAILED ===")
      head :bad_request
      return
    end

    # Extract collection from payload
    collection = payload.dig('collection')
    Rails.logger.info("=== COLLECTION EXTRACTION ===")
    Rails.logger.info("Extracted collection: #{collection.inspect}")
    Rails.logger.info("Collection present? #{collection.present?}")
    Rails.logger.info("Collection blank? #{collection.blank?}")

    # If collection is missing, try alternative locations (for Flow payloads)
    if collection.blank?
      Rails.logger.warn("❌ Directus webhook received without collection field")
      Rails.logger.warn("Checking alternative payload structures...")

      # Check if collection might be in trigger data
      trigger_data = payload.dig('payload', 'collection') || payload.dig('data', 'collection')
      if trigger_data.present?
        collection = trigger_data
        Rails.logger.info("✅ Found collection in alternative location: #{collection}")
      else
        Rails.logger.warn("❌ No collection found in payload")
        Rails.logger.warn("Available payload keys: #{payload.keys.inspect}")
        Rails.logger.warn("Full payload for debugging: #{payload.inspect}")
        Rails.logger.warn("📤 Response: 400 Bad Request")
        Rails.logger.warn("=== DIRECTUS WEBHOOK FAILED ===")
        head :bad_request
        return
      end
    end

    # Check cached collections
    cached_collections = DirectusCachedCollection.cached_collection_names
    Rails.logger.info("Available cached collections: #{cached_collections.inspect}")

    # Handle language configuration collections
    if LANGUAGE_CONFIG_COLLECTIONS.include?(collection)
      Rails.logger.info("📝 Directus webhook received for language config collection #{collection}, invalidating language cache")
      LanguageConfigurationService.invalidate_cache!
      Rails.logger.info("✅ Language cache invalidated successfully")
      Rails.logger.info("📤 Response: 200 OK")
      Rails.logger.info("=== DIRECTUS WEBHOOK COMPLETED ===")
      head :ok
      return
    end

    # Handle language configuration changes
    if collection == 'languages'
      Rails.logger.info("🌐 Directus webhook received for languages collection, updating language configuration")
      update_live_language_config
      Rails.logger.info("✅ Language configuration updated successfully")
      Rails.logger.info("📤 Response: 200 OK")
      Rails.logger.info("=== DIRECTUS WEBHOOK COMPLETED ===")
      head :ok
      return
    end

    # Check if collection is cached
    is_cached = cached_collections.include?(collection)
    Rails.logger.info("Collection '#{collection}' is cached: #{is_cached}")

    unless is_cached
      Rails.logger.info("🚫 Directus webhook received for uncached collection #{collection}, ignoring")
      Rails.logger.info("📤 Response: 200 OK (ignored)")
      Rails.logger.info("=== DIRECTUS WEBHOOK IGNORED ===")
      head :ok
      return
    end

    # Extract affected locales from nested translations in payload['payload']
    Rails.logger.info("Extracting affected locales from payload...")
    begin
      affected_locales = extract_affected_locales(payload)
      Rails.logger.info("Extracted affected locales: #{affected_locales.inspect}")
    rescue => e
      Rails.logger.error("❌ Error extracting locales: #{e.message}")
      Rails.logger.error("This might indicate malformed payload structure from Directus Flow")
      Rails.logger.error("Full payload: #{payload.inspect}")
      affected_locales = []  # Default to empty array
    end

    Rails.logger.info("🔄 Directus webhook received for collection #{collection}, invalidating cache and warming with #{affected_locales.length} locales")

    # Invalidate the collection cache
    Rails.logger.info("🗑️  Invalidating collection cache for: #{collection}")
    begin
      DirectusService.invalidate_collection!(collection)
      Rails.logger.info("✅ Collection cache invalidated successfully")
    rescue => e
      Rails.logger.error("❌ Failed to invalidate collection cache: #{e.message}")
      Rails.logger.error("📤 Response: 500 Internal Server Error")
      Rails.logger.error("=== DIRECTUS WEBHOOK ERROR ===")
      head :internal_server_error
      return
    end

    # Enqueue warmer job with affected locales (fallback to nil = all locales)
    locales_to_warm = affected_locales.presence || nil
    Rails.logger.info("📋 Enqueueing warmer job with locales: #{locales_to_warm.inspect}")

    begin
      DirectusCollectionWarmerJob.perform_later(collection, locales_to_warm)
      Rails.logger.info("✅ Warmer job enqueued successfully")
    rescue => e
      Rails.logger.error("❌ Failed to enqueue warmer job: #{e.message}")
      Rails.logger.error("📤 Response: 500 Internal Server Error")
      Rails.logger.error("=== DIRECTUS WEBHOOK ERROR ===")
      head :internal_server_error
      return
    end

    end_time = Time.current
    duration = end_time - start_time
    Rails.logger.info("🎉 Directus webhook processing completed successfully")
    Rails.logger.info("⏱️  Processing time: #{duration.round(4)} seconds")
    Rails.logger.info("📤 Response: 200 OK")
    Rails.logger.info("=== DIRECTUS WEBHOOK COMPLETED ===")
    head :ok
  end

  private

  # Extract affected locales from nested translations in payload['payload']
  def extract_affected_locales(payload)
    Rails.logger.info("🔍 Extracting affected locales from payload...")
    Rails.logger.info("Full payload structure: #{payload.inspect}")
    Rails.logger.info("Payload keys: #{payload.keys.inspect}")

    item_data = payload.dig('payload')
    Rails.logger.info("Payload['payload'] type: #{item_data.class}")
    Rails.logger.info("Payload['payload'] present? #{item_data.present?}")
    Rails.logger.info("Payload['payload'] content: #{item_data.inspect if item_data}")

    return [] unless item_data.is_a?(Hash)

    Rails.logger.info("Payload['payload'] is a Hash, checking for translations...")
    Rails.logger.info("Payload['payload'] keys: #{item_data.keys.inspect}")

    translations = item_data['translations'] || []
    Rails.logger.info("📝 Found #{translations.length} translation entries")
    Rails.logger.info("Translation details: #{translations.inspect}")
    Rails.logger.info("Translations type: #{translations.class}")

    # Handle case where translations might be malformed
    if translations.is_a?(Array)
      Rails.logger.info("Processing translations array...")
      locales = translations.map { |t|
        Rails.logger.debug("Processing translation entry: #{t.inspect} (type: #{t.class})")
        if t.is_a?(Hash)
          lang_code = t['languages_code'] || t['code'] || t['locale']
          Rails.logger.debug("Found languages_code: #{lang_code.inspect}")
          lang_code
        elsif t.is_a?(String)
          Rails.logger.debug("Translation entry is a string: #{t}")
          t  # Use the string directly as locale code
        else
          Rails.logger.warn("Unexpected translation entry type: #{t.class}")
          nil
        end
      }.compact.uniq
    else
      Rails.logger.warn("⚠️  Translations is not an array! Type: #{translations.class}")
      locales = []
    end

    Rails.logger.info("🎯 Extracted locales: #{locales.inspect}")

    locales
  rescue => e
    Rails.logger.error("❌ Error extracting locales: #{e.message}")
    Rails.logger.error("Error backtrace: #{e.backtrace.first(5).join("\n")}")
    []
  end

  # Build a realistic Directus webhook payload for simulation
  def build_simulated_payload(collection, action, locales)
    item_id = SecureRandom.uuid
    event = "items.#{action}"

    # Build translations array based on locales
    translations = locales.map do |locale|
      {
        'id' => SecureRandom.uuid,
        'languages_code' => locale,
        'title' => "Sample #{collection.singularize} title in #{locale}",
        'content' => "Sample content for #{collection.singularize} in #{locale} language.",
        'languages_id' => locale
      }
    end

    # Build the payload structure that Directus sends
    {
      'event' => event,
      'collection' => collection,
      'key' => item_id,
      'payload' => {
        'id' => item_id,
        'status' => 'published',
        'author' => 'admin-user-id',
        'date_created' => Time.current.iso8601,
        'date_updated' => Time.current.iso8601,
        'translations' => translations
      }
    }
  end

  # Simulate webhook processing directly without HTTP request mocking
  def simulate_webhook_processing(payload)
    collection = payload.dig('collection')

    # Handle language configuration changes (same as real webhook)
    if LANGUAGE_CONFIG_COLLECTIONS.include?(collection)
      Rails.logger.info("Simulating webhook processing for languages collection, updating language configuration")
      update_live_language_config
      return {
        processed: true,
        collection: collection,
        action: 'language_config_updated',
        message: 'Language configuration updated live'
      }
    end

    # Check if collection is cached
    unless DirectusCachedCollection.cached_collection_names.include?(collection)
      return {
        skipped: true,
        reason: "Collection #{collection} not in cached collections list",
        cached_collections: DirectusCachedCollection.cached_collection_names
      }
    end

    # Extract affected locales
    affected_locales = extract_affected_locales(payload)

    Rails.logger.info("Simulating webhook processing for collection #{collection}, invalidating cache and warming with #{affected_locales.length} locales")

    # Invalidate the collection cache
    begin
      DirectusService.invalidate_collection!(collection)
      cache_invalidated = true
    rescue => e
      Rails.logger.error("Failed to invalidate cache for #{collection}: #{e.message}")
      cache_invalidated = false
    end

    # Enqueue warmer job with affected locales (fallback to nil = all locales)
    locales_to_warm = affected_locales.presence || nil
    begin
      DirectusCollectionWarmerJob.perform_now(collection, locales_to_warm)
      job_enqueued = true
    rescue => e
      Rails.logger.error("Failed to enqueue warmer job for #{collection}: #{e.message}")
      job_enqueued = false
    end

    {
      processed: true,
      collection: collection,
      affected_locales: affected_locales,
      locales_to_warm: locales_to_warm,
      cache_invalidated: cache_invalidated,
      job_enqueued: job_enqueued
    }
  end
end
