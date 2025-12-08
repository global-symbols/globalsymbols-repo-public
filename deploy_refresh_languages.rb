#!/usr/bin/env ruby
# Deployment script to refresh language configuration
# Run this after adding new languages to Directus or during deployments

require_relative 'config/environment'

puts "🔄 Refreshing Language Configuration from Directus"
puts "=" * 60

begin
  # Check Directus connection
  puts "Checking Directus connection..."
  languages = DirectusService.fetch_collection('languages')
  puts "✅ Found #{languages.size} languages in Directus"

  # Refresh language configuration
  puts "\nRefreshing language configuration..."
  result = LanguageConfigurationService.update_live_config

  if result
    puts "✅ Language configuration updated successfully"

    # Show current configuration
    puts "\n📊 Current Configuration:"
    puts "Available Rails locales: #{I18n.available_locales.inspect}"
    puts "Directus language mappings: #{DIRECTUS_LANGUAGE_MAPPING.call.inspect}"
    puts "Default language: #{DIRECTUS_DEFAULT_LANGUAGE.call}"

    # Verify cache is populated
    cache_key = LanguageConfigurationService::CACHE_KEY
    cached_config = Rails.cache.read(cache_key)
    if cached_config.present?
      puts "✅ Cache populated with #{cached_config['available_locales'].size} locales"
    else
      puts "❌ WARNING: Cache not populated!"
    end

    # Test key mappings
    puts "\n🧪 Testing key language mappings:"
    [:en, :fr, :de, :es, :it, :nl].each do |locale|
      mapped = DIRECTUS_LANGUAGE_MAPPING.call[locale]
      status = mapped ? "✅" : "❌"
      puts "  #{locale} → #{mapped || 'nil'} #{status}"
    end

    puts "\n🎉 Language configuration refresh complete!"
    puts "   Cache warmed and ready for immediate use."
    puts "   Languages will persist across Puma restarts."
    puts ""
    puts "💡 For development testing, you can also visit:"
    puts "   http://localhost:3000/webhooks/directus/simulate?collection=languages"

  else
    puts "❌ Failed to update language configuration"
    exit 1
  end

rescue => e
  puts "❌ Error: #{e.message}"
  puts "Make sure Directus is accessible and environment variables are set:"
  puts "  - DIRECTUS_URL"
  puts "  - DIRECTUS_TOKEN_CMS"
  exit 1
end
