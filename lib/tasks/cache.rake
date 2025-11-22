# lib/tasks/cache.rake
namespace :cache do
  desc "Warm all Directus caches for current environment (run after deployments)"
  task warm_all: :environment do
    puts "Starting manual cache warming for #{Rails.env} environment..."
    puts "This may take several minutes depending on collection sizes."
    puts ""

    start_time = Time.current

    # Check if Directus is configured
    unless ENV['DIRECTUS_URL'].present? && ENV['DIRECTUS_TOKEN_CMS'].present?
      puts "❌ ERROR: Directus not configured. Set DIRECTUS_URL and DIRECTUS_TOKEN_CMS environment variables."
      exit 1
    end

    # Test Directus connection first
    puts "Testing Directus connection..."
    connection_test = DirectusService.test_connection
    if connection_test[:success]
      puts "✅ Directus connection successful"
    else
      puts "❌ ERROR: Directus connection failed: #{connection_test[:error]}"
      exit 1
    end

    # Warm all collections that the app caches
    collections_warmed = 0
    collections_failed = 0

    DirectusCollectionWarmerJob::COLLECTION_PARAMS_MAP.each_key do |collection|
      puts ""
      puts "🔄 Warming collection: #{collection}"
      begin
        # Warm with all locales (nil means all locales)
        DirectusCollectionWarmerJob.perform_now(collection, nil)
        puts "✅ Successfully warmed #{collection}"
        collections_warmed += 1
      rescue => e
        puts "❌ Failed to warm #{collection}: #{e.message}"
        collections_failed += 1
      end
    end

    # Also warm language configuration
    puts ""
    puts "🔄 Warming language configuration..."
    begin
      LanguageConfigurationService.config
      puts "✅ Successfully warmed language configuration"
    rescue => e
      puts "❌ Failed to warm language configuration: #{e.message}"
    end

    end_time = Time.current
    duration = end_time - start_time

    puts ""
    puts "🎉 Cache warming completed!"
    puts "   Duration: #{duration.round(2)} seconds"
    puts "   Collections warmed: #{collections_warmed}"
    puts "   Collections failed: #{collections_failed}"

    if collections_failed > 0
      puts "⚠️  Some collections failed to warm. Check logs for details."
      exit 1
    else
      puts "✅ All collections warmed successfully."
    end
  end

  desc "Check cache status and Directus connectivity"
  task status: :environment do
    puts "Cache Status Check for #{Rails.env}"
    puts "=" * 40

    # Check Redis connection
    begin
      redis = Rails.cache.redis
      db_size = redis.dbsize
      puts "✅ Redis connected (DB #{redis.connection[:db]}: #{db_size} keys)"
    rescue => e
      puts "❌ Redis connection failed: #{e.message}"
    end

    # Check Directus configuration
    directus_configured = ENV['DIRECTUS_URL'].present? && ENV['DIRECTUS_TOKEN_CMS'].present?
    puts "Directus configured: #{directus_configured ? '✅' : '❌'}"

    if directus_configured
      # Test Directus connection
      connection_test = DirectusService.test_connection
      puts "Directus connection: #{connection_test[:success] ? '✅' : '❌'}"

      if connection_test[:success]
        # Check current cache keys
        cache_keys = Rails.cache.redis.keys("directus/*")
        puts "Cached Directus responses: #{cache_keys.length}"

        if cache_keys.any?
          puts "Sample cache keys:"
          cache_keys.first(3).each { |key| puts "  - #{key}" }
        end
      end
    end
  end
end
