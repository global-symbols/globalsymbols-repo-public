#!/usr/bin/env ruby
# Debug cache operations

require_relative 'config/environment'

puts "🔍 Cache Debug"
puts "=" * 20

puts "\n1. Cache store info:"
puts "Rails.cache.class: #{Rails.cache.class}"
puts "Rails.cache.options: #{Rails.cache.options.inspect}"

puts "\n2. Basic cache operations:"
test_key = "test_key_#{Time.now.to_i}"
test_value = { "test" => "data", "timestamp" => Time.now }

puts "Writing test data..."
write_result = Rails.cache.write(test_key, test_value, expires_in: 1.hour)
puts "Write result: #{write_result.inspect}"

puts "Reading test data..."
read_result = Rails.cache.read(test_key)
puts "Read result: #{read_result.inspect}"

if read_result == test_value
  puts "✅ Basic cache operations work"
else
  puts "❌ Basic cache operations failed!"
end

puts "\n3. Language cache specific:"
lang_cache_key = LanguageConfigurationService::CACHE_KEY
puts "Language cache key: #{lang_cache_key.inspect}"

# Try to write language data directly
lang_data = {
  'available_locales' => [:en, :fr],
  'directus_mapping' => { en: 'en-GB', fr: 'fr-FR' },
  'default_language' => 'en-GB'
}

puts "Writing language data directly..."
lang_write_result = Rails.cache.write(lang_cache_key, lang_data, expires_in: 90.minutes)
puts "Language write result: #{lang_write_result.inspect}"

puts "Reading language data..."
lang_read_result = Rails.cache.read(lang_cache_key)
puts "Language read result: #{lang_read_result.inspect}"

if lang_read_result.present?
  puts "✅ Language cache write/read works"
else
  puts "❌ Language cache write/read failed!"
end

puts "\n4. Cache stats:"
begin
  stats = Rails.cache.stats
  puts "Cache stats: #{stats.inspect}"
rescue => e
  puts "Could not get cache stats: #{e.message}"
end
