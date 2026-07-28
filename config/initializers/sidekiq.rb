require 'sidekiq'
require 'sidekiq-unique-jobs'
require 'uri'

# Prefer full REDIS_URL when set (legacy prod Sidekiq unit).
# Otherwise build from REDIS_IP / REDIS_PASSWORD / REDIS_DB.
# Pre-prod: REDIS_DB=0  |  Production: REDIS_DB=1
redis_url =
  if ENV['REDIS_URL'].present?
    ENV['REDIS_URL']
  else
    redis_ip = ENV['REDIS_IP'] || 'localhost'
    redis_password = ENV['REDIS_PASSWORD'] || ''
    redis_db = ENV['REDIS_DB'] || '0'
    encoded_password = URI.encode_www_form_component(redis_password)
    "redis://:#{encoded_password}@#{redis_ip}:6379/#{redis_db}"
  end

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url, network_timeout: 5, pool_timeout: 5 }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url, network_timeout: 5, pool_timeout: 5 }
end
