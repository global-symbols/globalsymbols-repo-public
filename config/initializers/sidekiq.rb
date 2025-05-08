require 'sidekiq'
require 'sidekiq-unique-jobs'
require 'uri'

# Fetch Redis IP and password from environment variables
redis_ip = ENV['REDIS_IP'] || 'localhost'  # Default to localhost for development
redis_password = ENV['REDIS_PASSWORD'] || ''  # Default to no password for development
encoded_password = URI.encode_www_form_component(redis_password)  # Encode the password to escape special characters
redis_db = ENV['REDIS_DB'] || '0'  # Default to database 0
redis_url = "redis://:#{encoded_password}@#{redis_ip}:6379/0"

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url, network_timeout: 5, pool_timeout: 5 }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url, network_timeout: 5, pool_timeout: 5 }
end
