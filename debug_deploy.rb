#!/usr/bin/env ruby
# Debug version of deploy_refresh_languages.rb

require_relative 'config/environment'

puts "🔧 Debug Deploy Script"
puts "=" * 30

puts "\n1. Environment check:"
puts "Rails.env: #{Rails.env}"
puts "DIRECTUS_URL present: #{ENV['DIRECTUS_URL'].present?}"
puts "DIRECTUS_TOKEN_CMS present: #{ENV['DIRECTUS_TOKEN_CMS'].present?}"

puts "\n2. Directus connection test:"
begin
  server_info = DirectusService.raw_get('server/info')
  puts "✅ Directus connection OK"
rescue => e
  puts "❌ Directus connection failed: #{e.message}"
  exit 1
end

puts "\n3. Fetch languages test:"
begin
  languages = DirectusService.fetch_collection('languages')
  puts "✅ Found #{languages.size} languages"

  # Show first few languages
  languages.first(3).each do |lang|
    puts "  - #{lang['name']}: code=#{lang['code']}, rails_code=#{lang['rails_code']}"
  end
rescue => e
  puts "❌ Failed to fetch languages: #{e.message}"
  exit 1
end

puts "\n4. LanguageConfigurationService test:"
begin
  puts "Calling update_live_config..."
  result = LanguageConfigurationService.update_live_config
  puts "update_live_config result: #{result.inspect}"
rescue => e
  puts "❌ update_live_config failed: #{e.message}"
  puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
  exit 1
end

puts "\n5. Cache verification:"
cache_key = LanguageConfigurationService::CACHE_KEY
puts "Cache key: #{cache_key.inspect}"

cached_config = Rails.cache.read(cache_key)
if cached_config.present?
  puts "✅ Cache populated successfully"
  puts "Cached locales: #{cached_config['available_locales'].inspect}"
else
  puts "❌ Cache is still empty after update!"
end

puts "\n6. Final state:"
puts "I18n.available_locales: #{I18n.available_locales.inspect}"
puts "LanguageConfig.available_locales: #{LanguageConfig.available_locales.inspect}"
