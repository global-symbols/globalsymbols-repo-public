#!/usr/bin/env ruby

# Script to clear language cache and reload fresh configuration
require_relative 'config/environment'

puts "Clearing language configuration cache..."

begin
  # Clear the cache
  LanguageConfigurationService.invalidate_cache!
  puts "✅ Cache cleared"

  # Reload fresh configuration
  success = LanguageConfigurationService.update_live_config
  puts "✅ Language configuration reloaded: #{success}"

  # Show current state
  puts "Current available locales: #{I18n.available_locales.inspect}"
  puts "Current language mapping: #{LanguageConfigurationService.directus_language_mapping.inspect}"

rescue => e
  puts "❌ Error: #{e.message}"
  puts e.backtrace
end
