#!/usr/bin/env ruby
# Test script to check Directus languages collection
require_relative 'config/environment'

puts "Testing Directus languages collection..."
puts "=" * 50

begin
  languages = DirectusService.fetch_collection('languages')

  puts "Found #{languages.size} languages in Directus:"
  puts ""

  languages.each do |lang|
    code = lang['code']
    rails_code = lang['rails_code']
    name = lang['name'] || 'Unknown'

    status = rails_code.present? ? "✅ ACTIVE" : "❌ MISSING rails_code"
    puts "#{status} | #{code} | rails_code: '#{rails_code}' | #{name}"
  end

  puts ""
  puts "Languages that will appear in Rails app:"
  active_languages = languages.select { |l| l['rails_code'].present? }
  active_languages.each do |lang|
    puts "- #{lang['code']} -> #{lang['rails_code']}"
  end

  puts ""
  puts "Summary: #{active_languages.size}/#{languages.size} languages have rails_code set"

rescue => e
  puts "Error: #{e.message}"
  puts "Make sure Directus is configured and accessible"
end
