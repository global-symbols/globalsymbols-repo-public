#!/usr/bin/env ruby

# Test script to check language configuration
require_relative 'config/environment'

puts "Testing LanguageConfigurationService..."

begin
  # Clear cache first
  Rails.cache.clear
  puts "Cache cleared"

  # Test direct fetch
  config = LanguageConfigurationService.config
  puts "Config: #{config.inspect}"

  puts "Available locales: #{LanguageConfigurationService.available_locales.inspect}"
  puts "Directus mapping: #{LanguageConfigurationService.directus_language_mapping.inspect}"

  # Test update_live_config
  puts "Testing update_live_config..."
  result = LanguageConfigurationService.update_live_config
  puts "Update result: #{result}"

  puts "After update - Available locales: #{I18n.available_locales.inspect}"

rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace
end