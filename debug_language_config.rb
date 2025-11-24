#!/usr/bin/env ruby
# Debug script to check current language configuration state

require_relative 'config/environment'

puts "🔍 Language Configuration Debug"
puts "=" * 50

puts "\n📊 Current State:"
puts "I18n.available_locales: #{I18n.available_locales.inspect}"
puts "LanguageConfig.available_locales: #{LanguageConfig.available_locales.inspect}"
puts "LanguageConfig.language_mapping: #{LanguageConfig.language_mapping.inspect}"
puts "LanguageConfig.default_language: #{LanguageConfig.default_language.inspect}"

puts "\n🔗 Constants:"
puts "DIRECTUS_LANGUAGE_MAPPING.call: #{DIRECTUS_LANGUAGE_MAPPING.call.inspect}"
puts "DIRECTUS_DEFAULT_LANGUAGE.call: #{DIRECTUS_DEFAULT_LANGUAGE.call.inspect}"

puts "\n💾 Global Variables:"
puts "$directus_language_mapping: #{$directus_language_mapping.inspect}"
puts "$directus_default_language: #{$directus_default_language.inspect}"

puts "\n🗄️ Cache Check:"
cache_key = LanguageConfigurationService::CACHE_KEY
cached_config = Rails.cache.read(cache_key)
puts "Cached config exists: #{cached_config.present?}"
if cached_config
  puts "Cached available_locales: #{cached_config['available_locales'].inspect}"
end

puts "\n✅ Directus Connection:"
begin
  languages = DirectusService.fetch_collection('languages')
  puts "Found #{languages.size} languages in Directus"

  puts "\n📋 Language Details:"
  languages.each do |lang|
    puts "  #{lang['name'] || 'unnamed'}: code=#{lang['code']}, rails_code=#{lang['rails_code']}, default=#{lang['default']}"
  end

  # Test fetch_fresh_config directly
  puts "\n🔄 Testing fetch_fresh_config:"
  fresh_config = LanguageConfigurationService.send(:fetch_fresh_config)
  puts "Fresh config available_locales: #{fresh_config['available_locales'].inspect}"
  puts "Fresh config directus_mapping: #{fresh_config['directus_mapping'].inspect}"
  puts "Fresh config default_language: #{fresh_config['default_language'].inspect}"

  puts "\n✅ Language configuration is loaded during Rails startup in all environments"

rescue => e
  puts "❌ Directus connection failed: #{e.message}"
  puts "Error details: #{e.backtrace.first}"
end

puts "\n🎯 Conclusion:"
if I18n.available_locales == [:en] && LanguageConfig.available_locales != [:en]
  puts "❌ MISMATCH: I18n.available_locales is still [:en] but LanguageConfig has been updated!"
  puts "   This suggests I18n.available_locales is being reset somewhere after update_live_config"
elsif I18n.available_locales == LanguageConfig.available_locales
  puts "✅ MATCH: I18n.available_locales matches LanguageConfig.available_locales"
else
  puts "❓ UNKNOWN: Different configurations detected"
end
