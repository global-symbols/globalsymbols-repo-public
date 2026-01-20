# frozen_string_literal: true

namespace :webhook do
  desc 'Simulate Directus webhook calls for testing cache invalidation and warming'
  task :simulate, [:collection, :locales] => :environment do |t, args|
    collection = args[:collection] || 'articles'
    crud_action = 'update'  # Always use 'update' for simulation
    locales = (args[:locales] || 'en-GB,fr-FR').split(',').map(&:strip)

    puts "Simulating Directus webhook..."
    puts "Collection: #{collection}"
    puts "Locales: #{locales.join(', ')}"
    puts ""

    # Build the simulated payload
    payload = build_simulated_payload(collection, crud_action, locales)

    # Simulate the webhook processing
    result = simulate_webhook_processing(payload)

    puts "Simulation Results:"
    puts JSON.pretty_generate(result)
  end

  # Helper methods (copied from WebhooksController for rake task use)
  def build_simulated_payload(collection, action, locales)
    item_id = SecureRandom.uuid
    event = "items.#{action}"

    translations = locales.map do |locale|
      {
        'id' => SecureRandom.uuid,
        'gs_languages_code' => locale,
        'title' => "Sample #{collection.singularize} title in #{locale}",
        'content' => "Sample content for #{collection.singularize} in #{locale} language.",
        'languages_id' => locale
      }
    end

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

  def simulate_webhook_processing(payload)
    cached_collections = DirectusCachedCollection.cached_collection_names
    collection = payload.dig('collection')

    unless cached_collections.include?(collection)
      return {
        skipped: true,
        reason: "Collection #{collection} not in cached collections list",
        cached_collections: cached_collections
      }
    end

    affected_locales = extract_affected_locales(payload)

    puts "Processing webhook for collection #{collection}, warming #{affected_locales.length} locales"

    begin
      DirectusService.invalidate_collection!(collection)
      cache_invalidated = true
      puts "✓ Cache invalidated for #{collection}"
    rescue => e
      puts "✗ Failed to invalidate cache: #{e.message}"
      cache_invalidated = false
    end

    locales_to_warm = affected_locales.presence || nil
    begin
      DirectusCollectionWarmerJob.perform_now(collection, locales_to_warm)
      job_enqueued = true
      puts "✓ Warmer job executed for #{locales_to_warm || 'all'} locales"
    rescue => e
      puts "✗ Failed to execute warmer job: #{e.message}"
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

  def extract_affected_locales(payload)
    item_data = payload.dig('payload')
    return [] unless item_data.is_a?(Hash)

    translations = item_data['translations'] || []
    translations.map { |t|
      next nil unless t.is_a?(Hash)

      t['gs_languages_code'] || t['languages_code'] || t['code'] || t['locale'] || t['language']
    }.compact.uniq
  end
end
