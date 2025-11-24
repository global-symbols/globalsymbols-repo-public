# lib/tasks/cache.rake
namespace :cache do
  desc "Refresh language configuration from Directus (run when adding new languages)"
  task refresh_languages: :environment do
    puts "Refreshing language configuration from Directus..."

    # Check if Directus is configured
    unless ENV['DIRECTUS_URL'].present? && ENV['DIRECTUS_TOKEN_CMS'].present?
      puts "❌ ERROR: Directus not configured. Set DIRECTUS_URL and DIRECTUS_TOKEN_CMS environment variables."
      exit 1
    end

    # Update language configuration
    result = LanguageConfigurationService.update_live_config

    if result
      puts "✅ Language configuration refreshed successfully"
      puts "Available locales: #{I18n.available_locales.inspect}"
      puts "Language mappings: #{DIRECTUS_LANGUAGE_MAPPING.call.inspect}"
      puts "Default language: #{DIRECTUS_DEFAULT_LANGUAGE.call}"
    else
      puts "❌ Failed to refresh language configuration"
      exit 1
    end
  end

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

    # Track cache entries before warming
    initial_cache_count = count_cache_entries
    puts "Cache entries before warming: #{initial_cache_count}"

    # Clear existing cache to ensure fresh warming
    puts "Clearing existing Directus cache..."
    DirectusService.clear_cache!
    LanguageConfigurationService.invalidate_cache!
    puts "✅ Cache cleared"

    # Warm collections with detailed tracking
    total_expected_entries = 0
    total_actual_entries = 0

    DirectusCollectionWarmerJob::COLLECTION_PARAMS_MAP.each_key do |collection|
      puts ""
      puts "🔄 Warming collection: #{collection}"

      param_sets = DirectusCollectionWarmerJob::COLLECTION_PARAMS_MAP[collection]
      locales = DirectusCollectionWarmerJob::ALL_LOCALES
      expected_for_collection = param_sets.length  # 1 cache entry per unique API request

      puts "  Warming operations: #{param_sets.length * locales.length} (#{param_sets.length} param sets × #{locales.length} locales)"
      puts "  Expected cache entries: #{expected_for_collection} (#{param_sets.length} unique API requests)"
      total_expected_entries += expected_for_collection

      successful_locales = 0
      failed_locales = 0

      param_sets.each do |params|
        locales.each do |locale|
          begin
            # Force fresh fetch and cache
            DirectusService.fetch_collection_with_translations(
              collection,
              locale,
              params,
              nil, # cache_ttl = nil for indefinite caching
              false, # notify_missing = false to avoid spam during warming
              { force: true } # force refresh to ensure fresh data
            )
            successful_locales += 1
            print "."
          rescue => e
            failed_locales += 1
            print "x"
          end
        end
      end

      puts ""
      puts "  ✅ #{successful_locales} successful, ❌ #{failed_locales} failed for #{collection}"

      if failed_locales > 0
        puts "  ⚠️  Some #{collection} locales failed to cache"
      end
    end

    # Warm language configuration with verification
    puts ""
    puts "🔄 Warming language configuration..."
    begin
      # Force fresh fetch
      LanguageConfigurationService.invalidate_cache!
      config = LanguageConfigurationService.config

      # Verify it was actually cached
      cached_config = Rails.cache.read('directus/language_config')
      if cached_config
        puts "✅ Language configuration cached successfully"
        puts "  Available locales: #{cached_config['available_locales']&.length || 0}"
        total_actual_entries += 1
      else
        puts "❌ Language configuration fetch succeeded but was not cached"
      end
    rescue => e
      puts "❌ Failed to warm language configuration: #{e.message}"
    end

    # Final verification
    final_cache_count = count_cache_entries
    new_entries_created = final_cache_count  # We cleared cache first, so all entries are new

    end_time = Time.current
    duration = end_time - start_time

    puts ""
    puts "🎉 Cache warming completed!"
    puts "   Duration: #{duration.round(2)} seconds"
    puts "   Expected entries: #{total_expected_entries + 1}" # +1 for language config
    puts "   Cache entries created: #{new_entries_created}"
    puts "   Final cache count: #{final_cache_count}"

    # Debug: Show what keys actually exist
    puts ""
    puts "🔍 Cache verification:"
    show_sample_cache_entries

    if new_entries_created < (total_expected_entries + 1) * 0.8 # Less than 80% success
      puts "⚠️  WARNING: Cache warming incomplete. Expected #{total_expected_entries + 1} entries, got #{new_entries_created}"
      exit 1
    else
      puts "✅ Cache warming successful!"
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
        puts "Checking cache entries..."
        cache_count = count_cache_entries
        puts "Cached Directus entries: #{cache_count}"

        # Test Rails.cache.read directly
        puts "Testing Rails.cache.read for language config..."
        lang_config = Rails.cache.read('directus/language_config')
        if lang_config
          puts "✅ Language config readable via Rails.cache.read"
        else
          puts "❌ Language config NOT readable via Rails.cache.read"
        end

        # Test cache write/read cycle
        puts "Testing cache write/read cycle..."
        test_key = 'test/cache/debug'
        test_value = 'debug_value'
        Rails.cache.write(test_key, test_value, expires_in: 5.minutes)
        read_value = Rails.cache.read(test_key)
        if read_value == test_value
          puts "✅ Cache write/read cycle works"
        else
          puts "❌ Cache write/read cycle failed"
        end

        if cache_count > 0
          puts "Sample cache entries:"
          show_sample_cache_entries
        else
          puts "No cache entries found - running full diagnostic:"
          show_sample_cache_entries
        end
      end
    end
  end
end

def count_cache_entries
  begin
    cache_store = Rails.cache

    case cache_store
    when ActiveSupport::Cache::RedisCacheStore
      # Redis-based cache
      redis = cache_store.redis
      all_keys = redis.keys("*")
      directus_keys = all_keys.select { |k| k.include?('directus') }
      directus_keys.length

    when ActiveSupport::Cache::FileStore
      # File-based cache - count files in cache directory
      cache_dir = Rails.root.join('tmp', 'cache')
      if cache_dir.exist?
        # Count files that contain 'directus' in their path or content
        Dir.glob("#{cache_dir}/**/*").count do |file|
          File.file?(file) && (file.include?('directus') || File.read(file).include?('directus'))
        end
      else
        0
      end

    when ActiveSupport::Cache::MemoryStore
      # Memory store - we can't easily count entries
      puts "Note: MemoryStore doesn't support entry counting"
      1 if Rails.cache.read('directus/language_config') # At least check if language config exists

    else
      # Fallback - try to read known keys
      known_keys = ['directus/language_config', 'directus/articles', 'directus/users']
      known_keys.count { |key| Rails.cache.read(key) }
    end
  rescue => e
    puts "Error counting cache entries: #{e.message} (Cache store: #{Rails.cache.class})"
    0
  end
end

def count_cache_entries_cleared
  # We clear all directus cache entries before warming
  # Since we don't track the exact count cleared, we use 0 in calculations
  0
end

def show_sample_cache_entries
  begin
    cache_store = Rails.cache

    case cache_store
    when ActiveSupport::Cache::RedisCacheStore
      # Redis-based cache
      all_keys = cache_store.redis.keys("*")
    directus_keys = all_keys.select { |k| k.include?('directus') }

    puts "  Total Redis keys in DB: #{all_keys.length}"
    puts "  Directus-related keys: #{directus_keys.length}"

    if directus_keys.any?
      puts "  Sample cache entries:"
      directus_keys.first(5).each do |key|
        puts "    - #{key}"
      end
      puts "    ... and #{directus_keys.length - 5} more" if directus_keys.length > 5
    else
      puts "  No directus keys found. All keys in DB:"
      all_keys.first(10).each do |key|
        puts "    - #{key}"
      end
      puts "    ... and #{all_keys.length - 10} more" if all_keys.length > 10
      end

    when ActiveSupport::Cache::FileStore
      # File-based cache
      cache_dir = Rails.root.join('tmp', 'cache')
      if cache_dir.exist?
        cache_files = Dir.glob("#{cache_dir}/**/*").select { |f| File.file?(f) }
        directus_files = cache_files.select do |file|
          file.include?('directus') || File.read(file).include?('directus')
        end

        puts "  Total cache files: #{cache_files.length}"
        puts "  Directus-related files: #{directus_files.length}"

        if directus_files.any?
          puts "  Sample cache files:"
          directus_files.first(5).each do |file|
            relative_path = file.sub("#{cache_dir}/", '')
            puts "    - #{relative_path}"
          end
          puts "    ... and #{directus_files.length - 5} more" if directus_files.length > 5
        else
          puts "  No directus cache files found. Sample files:"
          cache_files.first(5).each do |file|
            relative_path = file.sub("#{cache_dir}/", '')
            puts "    - #{relative_path}"
          end
        end
      else
        puts "  Cache directory doesn't exist: #{cache_dir}"
      end

    when ActiveSupport::Cache::MemoryStore
      puts "  MemoryStore doesn't support file listing"
      puts "  Language config cached: #{Rails.cache.read('directus/language_config') ? '✅' : '❌'}"

    else
      puts "  Unsupported cache store: #{cache_store.class}"
    end
  rescue => e
    puts "  Error listing cache entries: #{e.message} (Cache store: #{Rails.cache.class})"
  end
end
