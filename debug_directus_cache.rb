#!/usr/bin/env ruby
# Debug script for Directus cache warming issue
# Run with: ruby debug_directus_cache.rb

require 'bundler/setup'
require 'rails'
require_relative 'config/environment'

puts "🔧 Debug Directus Cache Warming"
puts "=" * 50

# Load the warmer job to get locales
require_relative 'app/jobs/directus_collection_warmer_job'

# Test parameters (same as cache warming)
collection = 'articles'
locales = DirectusCollectionWarmerJob::ALL_LOCALES
param_sets = DirectusCachedCollection.collection_params_map[collection]

puts "📊 Test Configuration:"
puts "Collection: #{collection}"
puts "Locales: #{locales.length} (#{locales.first(3).join(', ')}...)"
puts "Parameter sets: #{param_sets.length}"
puts ""

# Monkey patch DirectusService to add debugging
class DirectusService
  class << self
    alias_method :original_fetch_collection_with_translations, :fetch_collection_with_translations
    alias_method :original_request, :request
  end

  def self.fetch_collection_with_translations(collection, language_code, params = {}, cache_ttl = nil, notify_missing = true, options = {})
    puts "🎯 Testing: #{collection} / #{language_code}"
    puts "   Params: #{params.keys.join(', ')}"

    begin
      # Call original method
      result = original_fetch_collection_with_translations(collection, language_code, params, cache_ttl, notify_missing, options)
      puts "   ✅ SUCCESS"
      result
    rescue => e
      puts "   ❌ FAILED: #{e.message}"
      puts "   Error class: #{e.class}"

      # Re-run with detailed debugging
      puts "\n🔍 DEBUGGING FAILURE..."
      debug_fetch_collection_with_translations(collection, language_code, params, cache_ttl, notify_missing, options)

      raise e
    end
  end

  def self.request(method, path, params = {}, cache_ttl = nil)
    puts "   🔍 Request: #{method.upcase} #{path}"

    begin
      cache_key = build_cache_key(method, path, params)
      puts "   🔍 Cache key: #{cache_key[0..50]}..."

      result = Rails.cache.fetch(cache_key, expires_in: cache_ttl) do
        puts "   🔍 Making API call..."

        response = faraday_connection.send(method) do |req|
          req.url path
          req.params = params if params.present?
        end

        puts "   🔍 Response status: #{response.status}"
        puts "   🔍 Response success: #{response.success?}"

        handle_response(response)
      end

      puts "   🔍 Request completed successfully"
      result
    rescue => e
      puts "   💥 REQUEST ERROR: #{e.message} (#{e.class})"
      raise e
    end
  end

  def self.debug_fetch_collection_with_translations(collection, language_code, params = {}, cache_ttl = nil, notify_missing = true, options = {})
    puts "   Step 1: Building translation params..."
    translation_params = build_translation_params(language_code, params)
    puts "   Step 2: Fetching collection..."

    begin
      items = fetch_collection(collection, translation_params, cache_ttl)
      puts "   Step 3: Got #{items.length} items from API"

      puts "   Step 4: Filtering items..."
      filtered_items = items.select do |item|
        translations = item['translations'] || []
        has_requested_language = translations.any? { |t| t['gs_languages_code'] == language_code }
        has_fallback_language = translations.any? { |t| t['gs_languages_code'] == DIRECTUS_DEFAULT_LANGUAGE.call }

        has_requested_language || has_fallback_language
      end

      puts "   Step 5: Filtered to #{filtered_items.length} items"
      puts "   Step 6: Calculating missing translations..."

      # This is the line that should fail
      missing_translations = items - filtered_items
      puts "   Step 7: Missing translations calculated (#{missing_translations.length} items)"

      puts "   Step 8: Processing complete"

    rescue => inner_e
      puts "   💥 ERROR at this step: #{inner_e.message}"
      puts "   Error location: #{inner_e.backtrace.first}"

      # Show data samples if possible
      if defined?(items) && items
        puts "   Sample item data:"
        puts "   Item 0 keys: #{items.first&.keys&.join(', ')}" if items.first
        puts "   Item 0 translations: #{items.first&.dig('translations')&.length} translations" if items.first
      end

      raise inner_e
    end
  end
end

# Test just the first combination (should be enough to trigger the error)
puts "🧪 Running test..."
begin
  DirectusService.fetch_collection_with_translations(
    collection,
    locales.first,  # Test first locale
    param_sets.first,  # Test first param set
    nil,     # cache_ttl
    false,   # notify_missing (same as cache warming)
    { force: true }
  )
  puts "\n✅ No error occurred - issue may be elsewhere"
rescue => e
  puts "\n💥 Error reproduced: #{e.message}"
  puts "\nThis confirms the issue is in fetch_collection_with_translations"
end

puts "\n🎯 Debug complete"
