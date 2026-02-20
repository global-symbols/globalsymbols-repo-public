# frozen_string_literal: true

# Rack::Attack uses Redis DB from REDIS_DB env var (same DB as Sidekiq) for throttling.
# Production: REDIS_DB=1, Pre-prod: REDIS_DB=0, Stage: REDIS_DB=0
# Defaults to DB 999 if REDIS_DB is not set (safety fallback).
# In development, falls back to Rails.cache (file store).
# See https://github.com/rack/rack-attack

# Use Redis for production-like environments (production, pre-prod, stage)
if Rails.env.production? || Rails.env.pre_prod? || Rails.env.stage?
  redis_ip = ENV['REDIS_IP']
  redis_password = ENV['REDIS_PASSWORD'] || ''
  redis_db = ENV['REDIS_DB'] || '999'  # Default to DB 999 if not set (safety fallback)
  
  if redis_ip.present?
    require 'uri'
    encoded_password = URI.encode_www_form_component(redis_password)
    redis_url = "redis://:#{encoded_password}@#{redis_ip}:6379/#{redis_db}"
    
    # Create a dedicated Redis cache store for Rack::Attack
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: redis_url,
      namespace: 'rack_attack',
      reconnect_attempts: 3
    )
  else
    # Fallback to Rails.cache if Redis config is missing
    Rack::Attack.cache.store = Rails.cache
  end
else
  # Development/test: use Rails.cache (file store in dev, memory in test)
  Rack::Attack.cache.store = Rails.cache
end

# API: 100 requests per minute per IP
Rack::Attack.throttle('api/ip', limit: 100, period: 1.minute) do |req|
  req.ip if req.path.start_with?('/api')
end

# Non-API: 300 requests per minute per IP
Rack::Attack.throttle('non-api/ip', limit: 300, period: 1.minute) do |req|
  req.ip unless req.path.start_with?('/api')
end

# Return 429 with JSON body and Retry-After for throttled requests
Rack::Attack.throttled_responder = lambda do |request|
  period = request.env['rack.attack.match_data'][:period]
  headers = {
    'Content-Type' => 'application/json',
    'Retry-After' => period.to_s
  }
  [429, headers, [{ error: 'Rate limit exceeded. Please slow down.' }.to_json]]
end
