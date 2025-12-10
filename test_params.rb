#!/usr/bin/env ruby
# Test parameter encoding fix
require 'bundler/setup'
require 'rails'
require_relative 'config/environment'

puts "Testing parameter encoding fix..."

# Test the fixed build_translation_params method
params = DirectusService.send(:build_translation_params, 'en-GB')
puts "Params: #{params.inspect}"

# Test if params can be JSON serialized (used in cache key)
begin
  json = params.to_json
  puts "✅ JSON serialization works: #{json.length} chars"
rescue => e
  puts "❌ JSON serialization failed: #{e.message}"
end

# Test Faraday parameter encoding (simulate what happens in the request)
begin
  require 'faraday'
  conn = Faraday.new do |faraday|
    faraday.request :url_encoded
  end

  # This simulates what happens when params are set on the request
  test_req = conn.build_request(:get) do |req|
    req.params = params
  end

  puts "✅ Faraday parameter encoding works"
rescue => e
  puts "❌ Faraday parameter encoding failed: #{e.message}"
  puts "Error: #{e.backtrace.first}"
end

puts "Test complete"
