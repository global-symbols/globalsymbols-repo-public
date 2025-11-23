# frozen_string_literal: true

class DirectusCollectionWarmerJob < ApplicationJob
  queue_as :default

  # Map of collections to their parameter sets used in the application
  # Each collection contains an array of parameter hashes that the app actually uses
  COLLECTION_PARAMS_MAP = {
    'articles' => [
      { limit: 1000 },  # Used by articles index for pagination/filtering
      { limit: 9 }      # Used for featured articles or small lists
    ]
  }.freeze

  # All supported Directus language codes (from config/initializers/locale.rb)
  ALL_LOCALES = %w[
    en-GB bg-BG ca-ES de-DE el-GR es-ES fr-FR hr-HR hy-AM it-IT
    mk-MK nl-NL ps-AF ro-RO sq-AL sr-RS tr-TR uk-UA ur-PK
  ].freeze

  def perform(collection, locales = nil)
    locales ||= ALL_LOCALES

    Rails.logger.info("Starting Directus collection warmer for #{collection} with #{locales.length} locales")

    # Get parameter sets for this collection
    param_sets = COLLECTION_PARAMS_MAP[collection]
    if param_sets.blank?
      Rails.logger.warn("No parameter sets found for collection #{collection}, skipping")
      return
    end

    # Warm cache for each parameter set and locale combination
    param_sets.each do |params|
      locales.each do |locale|
        begin
          Rails.logger.info("Warming cache for #{collection} with locale #{locale} and params #{params.inspect}")
          DirectusService.fetch_collection_with_translations(
            collection,
            locale,
            params,
            nil, # cache_ttl = nil for indefinite caching
            false, # notify_missing = false to avoid spam during warming
            { force: true } # force refresh to ensure fresh data
          )
        rescue => e
          Rails.logger.error("Failed to warm cache for #{collection}/#{locale} with params #{params.inspect}: #{e.message}")
          # Continue with other combinations even if one fails
        end
      end
    end

    Rails.logger.info("Completed Directus collection warmer for #{collection}")
  end
end
