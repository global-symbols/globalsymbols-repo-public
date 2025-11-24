#!/usr/bin/env ruby
# Verify that language cache is properly populated after deployment

require_relative 'config/environment'

puts "🔍 Cache Verification"
puts "=" * 30

cache_key = LanguageConfigurationService::CACHE_KEY
cached_config = Rails.cache.read(cache_key)

if cached_config.present?
  puts "✅ Cache populated successfully"
  puts "Available locales: #{cached_config['available_locales'].inspect}"
  puts "Language mappings count: #{cached_config['directus_mapping'].size}"
  puts "Default language: #{cached_config['default_language']}"

  # Test that the cache is working
  config_from_service = LanguageConfigurationService.config
  if config_from_service == cached_config
    puts "✅ Cache retrieval working correctly"
  else
    puts "❌ Cache retrieval mismatch!"
  end
else
  puts "❌ Cache is empty!"
  puts "Language configuration will fallback to defaults."
  puts "Run: ruby deploy_refresh_languages.rb"
end

puts "\nCurrent I18n state:"
puts "I18n.available_locales: #{I18n.available_locales.inspect}"
puts "LanguageConfig.available_locales: #{LanguageConfig.available_locales.inspect}"
