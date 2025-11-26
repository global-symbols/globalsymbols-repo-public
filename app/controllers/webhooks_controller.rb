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
    Rails.logger.info("Directus webhook received")

    # Verify webhook secret from Authorization header
    auth_header = request.headers['Authorization']
    unless auth_header == "Bearer #{DIRECTUS_WEBHOOK_SECRET}"
      Rails.logger.warn("Directus webhook authentication failed")
      head :unauthorized
      return
    end

    # Parse JSON payload
    begin
      payload = JSON.parse(request.body.read)
    rescue JSON::ParserError => e
      Rails.logger.error("Directus webhook invalid JSON: #{e.message}")
      head :bad_request
      return
    end

    # Extract collection from payload
    collection = payload.dig('collection')

    # If collection is missing, try alternative locations (for Flow payloads)
    if collection.blank?
      collection = payload.dig('payload', 'collection') || payload.dig('data', 'collection')
    end

    if collection.blank?
      Rails.logger.warn("Directus webhook missing collection")
      head :bad_request
      return
    end

    # Check if collection is cached
    cached_collections = DirectusCachedCollection.cached_collection_names

    # Handle special collections
    if LANGUAGE_CONFIG_COLLECTIONS.include?(collection)
      update_live_language_config
      Rails.logger.info("Directus webhook processed for special collection: #{collection}")
      head :ok
      return
    end

    unless cached_collections.include?(collection)
      Rails.logger.info("Directus webhook ignored - collection not cached: #{collection}")
      head :ok
      return
    end

    # Extract affected locales
    affected_locales = extract_affected_locales(payload) rescue []

    # Invalidate cache and enqueue warmer job
    DirectusService.invalidate_collection!(collection)

    locales_to_warm = affected_locales.presence
    DirectusCollectionWarmerJob.perform_later(collection, locales_to_warm)

    Rails.logger.info("Directus webhook processed - collection: #{collection}, locales: #{locales_to_warm || 'all'}")
    head :ok
  end

  private

  # Extract affected locales from nested translations in payload['payload']
  def extract_affected_locales(payload)
    item_data = payload.dig('payload')
    return [] unless item_data.is_a?(Hash)

    translations = item_data['translations'] || []

    # Handle different payload structures
    if translations.is_a?(Array)
      locales = translations.map { |t|
        if t.is_a?(Hash)
          t['languages_code'] || t['code'] || t['locale'] || t['language']
        elsif t.is_a?(String)
          t  # Use the string directly as locale code
        end
      }.compact.uniq
    elsif translations.is_a?(Hash)
      # If translations is a hash like {"en-GB": {...}, "fr-FR": {...}}, use the keys
      locales = translations.keys
    else
      locales = []
    end

    # If no locales found, try alternative extraction or default to all
    if locales.empty?
      # Look for common locale patterns in the payload
      all_text = payload.inspect
      potential_locales = ['en-GB', 'fr-FR', 'de-DE', 'es-ES', 'it-IT', 'nl-NL', 'pt-BR', 'zh-CN', 'ja-JP', 'ko-KR'].select do |locale|
        all_text.include?(locale)
      end

      locales = potential_locales.presence || ['en-GB', 'fr-FR', 'de-DE', 'es-ES', 'it-IT', 'nl-NL', 'pt-BR', 'zh-CN', 'ja-JP', 'ko-KR']
    end

    locales
  rescue => e
    Rails.logger.error("Error extracting locales: #{e.message}")
    ['en-GB', 'fr-FR']  # Minimal fallback
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
