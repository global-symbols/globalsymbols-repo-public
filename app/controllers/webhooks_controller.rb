# frozen_string_literal: true

class WebhooksController < ApplicationController
  # Webhooks should not require authentication
  skip_before_action :authenticate_user!

  # Collections that we cache and should respond to webhooks for
  CACHED_COLLECTIONS = %w[articles].freeze

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
    # Verify webhook secret from Authorization header
    auth_header = request.headers['Authorization']
    unless auth_header == "Bearer #{DIRECTUS_WEBHOOK_SECRET}"
      Rails.logger.warn("Directus webhook received with invalid authorization")
      head :unauthorized
      return
    end

    # Parse JSON payload
    begin
      payload = JSON.parse(request.body.read)
    rescue JSON::ParserError => e
      Rails.logger.error("Directus webhook received invalid JSON: #{e.message}")
      head :bad_request
      return
    end

    # Extract collection from payload
    collection = payload.dig('collection')
    if collection.blank?
      Rails.logger.warn("Directus webhook received without collection")
      head :bad_request
      return
    end

    # Handle language configuration collections
    if LANGUAGE_CONFIG_COLLECTIONS.include?(collection)
      Rails.logger.info("Directus webhook received for language config collection #{collection}, invalidating language cache")
      LanguageConfigurationService.invalidate_cache!
      head :ok
      return
    end

    # Skip if we don't cache this collection
    # Handle language configuration changes
    if collection == 'languages'
      Rails.logger.info("Directus webhook received for languages collection, updating language configuration")
      update_live_language_config
      head :ok
      return
    end

    unless CACHED_COLLECTIONS.include?(collection)
      Rails.logger.info("Directus webhook received for uncached collection #{collection}, ignoring")
      head :ok
      return
    end

    # Extract affected locales from nested translations in payload['payload']
    affected_locales = extract_affected_locales(payload)

    Rails.logger.info("Directus webhook received for collection #{collection}, invalidating cache and warming with #{affected_locales.length} locales")

    # Invalidate the collection cache
    DirectusService.invalidate_collection!(collection)

    # Enqueue warmer job with affected locales (fallback to nil = all locales)
    locales_to_warm = affected_locales.presence || nil
    DirectusCollectionWarmerJob.perform_later(collection, locales_to_warm)

    head :ok
  end

  private

  # Extract affected locales from nested translations in payload['payload']
  def extract_affected_locales(payload)
    item_data = payload.dig('payload')
    return [] unless item_data.is_a?(Hash)

    translations = item_data['translations'] || []
    translations.map { |t| t['languages_code'] }.compact.uniq
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
    unless CACHED_COLLECTIONS.include?(collection)
      return {
        skipped: true,
        reason: "Collection #{collection} not in cached collections list",
        cached_collections: CACHED_COLLECTIONS
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
