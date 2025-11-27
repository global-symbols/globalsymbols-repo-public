# frozen_string_literal: true

# Cache Inspector for Directus Cached Collections
# Load this in Rails console with: require 'cache_inspector'
#
# Usage:
#   require 'cache_inspector'
#   inspect_article_cache
#   article_cached?(4, 'en-GB')

module CacheInspector
  extend self

  # Check if a specific article is cached
  def article_cached?(id, language = 'en-GB')
    # First check if individually cached (though unlikely)
    translation_params = DirectusService.send(:build_translation_params, language, {})
    individual_cache_key = DirectusService.send(:build_cache_key, :get, "items/articles/#{id}", translation_params)
    individual_cached = Rails.cache.read(individual_cache_key)

    # Check if article exists in any collection caches
    redis = Rails.cache.redis
    collection_keys = redis.keys('globalsymbols_cache:directus/articles:*')
    found_in_collections = []
    article_details = nil

    collection_keys.each do |full_key|
      clean_key = full_key.sub('globalsymbols_cache:', '')
      begin
        cached_data = Rails.cache.read(clean_key)
        if cached_data.is_a?(Hash) && cached_data['data'].is_a?(Array)
          # Check if article ID exists in this collection and extract details
          article_item = cached_data['data'].find { |item| item.is_a?(Hash) && item['id'] == id }
          if article_item
            found_in_collections << clean_key
            article_details ||= article_item # Keep the first found article details
          elsif cached_data['data'].include?(id)
            found_in_collections << clean_key
            # If only ID is cached, we can't get details
          end
        end
      rescue => e
        # Skip problematic cache entries
      end
    end

    # Determine overall status
    individually_cached = individual_cached.present?
    in_collections = found_in_collections.any?

    if individually_cached
      status = '✅ CACHED (individual)'
    elsif in_collections
      status = '✅ CACHED (in collections)'
    else
      status = '❌ NOT CACHED'
    end

    puts "Article #{id} (#{language}): #{status}"

    # Show article details if available
    if article_details
      display_article_details(article_details)
    end

    if Rails.env.development?
      puts "Individual cache key: #{individual_cache_key}"
      redis = Rails.cache.redis
      full_individual_key = "globalsymbols_cache:#{individual_cache_key}"
      redis_exists = redis.exists(full_individual_key)
      puts "Individual Redis key exists: #{redis_exists ? 'YES' : 'NO'} (#{full_individual_key})"

      if in_collections
        puts "Found in #{found_in_collections.length} collection(s):"
        found_in_collections.each { |key| puts "  - #{key}" }
      end
    end

    individually_cached || in_collections
  end

  # Check if a specific article is cached and show FULL details (no truncation)
  def article_cached_full?(id, language = 'en-GB')
    # First check if individually cached (though unlikely)
    translation_params = DirectusService.send(:build_translation_params, language, {})
    individual_cache_key = DirectusService.send(:build_cache_key, :get, "items/articles/#{id}", translation_params)
    individual_cached = Rails.cache.read(individual_cache_key)

    # Check if article exists in any collection caches
    redis = Rails.cache.redis
    collection_keys = redis.keys('globalsymbols_cache:directus/articles:*')
    found_in_collections = []
    article_details = nil

    collection_keys.each do |full_key|
      clean_key = full_key.sub('globalsymbols_cache:', '')
      begin
        cached_data = Rails.cache.read(clean_key)
        if cached_data.is_a?(Hash) && cached_data['data'].is_a?(Array)
          # Check if article ID exists in this collection and extract details
          article_item = cached_data['data'].find { |item| item.is_a?(Hash) && item['id'] == id }
          if article_item
            found_in_collections << clean_key
            article_details ||= article_item # Keep the first found article details
          elsif cached_data['data'].include?(id)
            found_in_collections << clean_key
            # If only ID is cached, we can't get details
          end
        end
      rescue => e
        # Skip problematic cache entries
      end
    end

    # Determine overall status
    individually_cached = individual_cached.present?
    in_collections = found_in_collections.any?

    if individually_cached
      status = '✅ CACHED (individual - full details)'
    elsif in_collections
      status = '✅ CACHED (in collections - full details)'
    else
      status = '❌ NOT CACHED'
    end

    puts "Article #{id} (#{language}): #{status}"

    # Show FULL article details if available (no truncation)
    if article_details
      display_article_details(article_details, true)
    end

    if Rails.env.development?
      puts "Individual cache key: #{individual_cache_key}"
      redis = Rails.cache.redis
      full_individual_key = "globalsymbols_cache:#{individual_cache_key}"
      redis_exists = redis.exists(full_individual_key)
      puts "Individual Redis key exists: #{redis_exists ? 'YES' : 'NO'} (#{full_individual_key})"

      if in_collections
        puts "Found in #{found_in_collections.length} collection(s):"
        found_in_collections.each { |key| puts "  - #{key}" }
      end
    end

    individually_cached || in_collections
  end

  # Display article details from cache
  def display_article_details(article, full = false)
    puts "📄 Article Details:"

    # Basic info
    puts "   ID: #{article['id']}"
    puts "   Status: #{article['status']}"
    puts "   Featured: #{article['featured']}"

    # Dates
    if article['date_created']
      puts "   Created: #{Time.parse(article['date_created']).strftime('%Y-%m-%d %H:%M')}"
    end
    if article['date_updated']
      puts "   Updated: #{Time.parse(article['date_updated']).strftime('%Y-%m-%d %H:%M')}"
    end

    # Author
    if article['author'].is_a?(Hash)
      author_name = [article.dig('author', 'first_name'), article.dig('author', 'last_name')].compact.join(' ')
      puts "   Author: #{author_name.presence || 'Unknown'}"
    end

    # Slug
    if article['slug']
      puts "   Slug: #{article['slug']}"
    end

    # Categories
    if article['categories'].is_a?(Array) && article['categories'].any?
      category_names = article['categories'].map do |cat|
        if cat.is_a?(Hash) && cat.dig('article_categories_id', 'name')
          cat.dig('article_categories_id', 'name')
        elsif cat.is_a?(Hash)
          cat['name']
        else
          cat.to_s
        end
      end.compact
      puts "   Categories: #{category_names.join(', ')}" if category_names.any?
    end

    # Translations
    if article['translations'].is_a?(Array) && article['translations'].any?
      if article['translations'].first.is_a?(Hash)
        translation = article['translations'].first
        title = translation['title']
        if full
          puts "   Title: #{title}" if title
          puts "   Content: #{translation['content']}" if translation['content']
        else
          content_preview = translation['content']&.truncate(100)&.gsub(/\s+/, ' ')
          puts "   Title: #{title&.truncate(60)}" if title
          puts "   Content: #{content_preview}" if content_preview
        end
        puts "   Language: #{translation['languages_code']}" if translation['languages_code']
      elsif article['translations'].first.is_a?(Integer)
        puts "   Translations: #{article['translations'].length} language IDs available"
      end
    end

    # Image
    if article['image']
      puts "   Image: #{article['image']}"
    end
  rescue => e
    puts "   Error displaying article details: #{e.message}"
  end

  # Inspect all cached articles
  def inspect_article_cache
    redis = Rails.cache.redis
    keys = redis.keys('globalsymbols_cache:directus/articles:*')

    puts "=== ARTICLE CACHE INSPECTOR ==="
    puts "Total cached articles: #{keys.length}"
    puts "Redis namespace: globalsymbols_cache"
    puts "Collection: articles"
    puts ""

    if keys.empty?
      puts "❌ No articles cached"
      puts "💡 Try: DirectusService.fetch_item_with_translations('articles', 4, 'en-GB')"
      return
    end

    keys.each do |key|
      clean_key = key.sub('globalsymbols_cache:', '')
      puts "📄 #{clean_key}"

      # Try to read the cached data
      begin
        cached_data = Rails.cache.read(clean_key)
        if cached_data.is_a?(Hash) && cached_data['id']
          # Individual article cache
          title = cached_data.dig('translations', 0, 'title')
          status = cached_data['status']
          puts "   ID: #{cached_data['id']}, Status: #{status}, Title: #{title&.truncate(50)}"
        elsif cached_data.is_a?(Hash) && cached_data['data'].is_a?(Array)
          # Collection list cache
          article_count = cached_data['data'].length

          # Handle both formats: full objects or just IDs
          first_item = cached_data['data'].first
          if first_item.is_a?(Hash)
            # Full article objects
            ids = cached_data['data'].map { |a| a['id'] }.compact
            puts "   📋 Collection list: #{article_count} articles (IDs: #{ids.inspect})"

            # Show first few article titles
            cached_data['data'].first(3).each do |article|
              if article['translations'].is_a?(Array) && article['translations'].first.is_a?(Hash)
                title = article.dig('translations', 0, 'title')
                status = article['status']
                puts "      • ID #{article['id']}: #{title&.truncate(40)} (#{status})"
              elsif article['translations'].is_a?(Array) && article['translations'].first.is_a?(Integer)
                # Translations are just IDs, no title available
                status = article['status']
                puts "      • ID #{article['id']}: [No title - translations are IDs only] (#{status})"
              else
                # Unknown translations format
                status = article['status']
                puts "      • ID #{article['id']}: [Unknown translations format] (#{status})"
              end
            end
            puts "      ... and #{article_count - 3} more articles" if article_count > 3
          elsif first_item.is_a?(Integer)
            # Just IDs array
            ids = cached_data['data']
            puts "   📋 Collection list: #{article_count} article IDs (#{ids.inspect})"
            puts "      💡 These are just IDs - fetch individual articles for full data"
          else
            # Unknown format or empty array
            puts "   📋 Collection list: #{article_count} items (unknown format: #{first_item&.class})"
          end
        elsif cached_data.is_a?(Hash)
          puts "   Hash data (keys: #{cached_data.keys.inspect})"
        else
          puts "   Cached data type: #{cached_data.class}, value: #{cached_data.inspect}"
        end
      rescue => e
        puts "   Error reading cache: #{e.message}"
      end
    end

    puts ""
    puts "🎯 Usage:"
    puts "  article_cached?(ID, 'en-GB')  # Check specific article"
    puts "  Rails.cache.clear              # Clear all cache"
  end

  # Check if language is cached
  def language_cached?(code)
    # Build the same key that fetch_item would use for languages
    cache_key = DirectusService.send(:build_cache_key, :get, "items/languages/#{code}", {})

    cached_data = Rails.cache.read(cache_key)
    status = cached_data.present? ? '✅ CACHED' : '❌ NOT CACHED'

    puts "Language #{code}: #{status}"
    if Rails.env.development?
      puts "Cache key: #{cache_key}"

      if cached_data
        puts "Cached data type: #{cached_data.class}"
        if cached_data.is_a?(Hash)
          puts "Language name: #{cached_data['name']}"
          puts "Language code: #{cached_data['code']}"
        end
      end
    end
  end

  # Fetch and cache a specific language
  def fetch_and_cache_language(code)
    puts "🔄 Fetching and caching language #{code}..."

    begin
      language = DirectusService.fetch_item('languages', code)
      if language
        puts "✅ Language #{code} fetched and cached"
        puts "   Name: #{language['name']}"
        puts "   Code: #{language['code']}"

        # Verify it's now cached
        sleep 0.1 # Small delay to ensure caching
        cached = language_cached?(code)
        puts "   Verification: #{cached ? '✅ Now cached' : '❌ Still not cached'}"
      else
        puts "❌ Language #{code} not found in Directus"
      end
    rescue => e
      puts "❌ Error fetching language #{code}: #{e.message}"
    end
  end

  # Inspect cached languages
  def inspect_cached_languages
    redis = Rails.cache.redis

    # Check the known language config key first
    language_config_key = 'globalsymbols_cache:directus/language_config'
    has_language_config = redis.exists(language_config_key)

    # Try multiple patterns for individual languages
    patterns = [
      'globalsymbols_cache:directus/languages:*',
      'globalsymbols_cache:directus/*languages*',
      'globalsymbols_cache:*languages*'
    ]

    all_language_keys = []
    patterns.each do |pattern|
      keys = redis.keys(pattern)
      all_language_keys.concat(keys) unless keys.empty?
    end

    # Remove duplicates
    all_language_keys.uniq!

    puts "=== CACHED LANGUAGES ==="
    puts "Total cached languages: #{all_language_keys.length}"
    puts "Redis namespace: globalsymbols_cache"
    puts "Language config cached: #{has_language_config ? '✅ YES' : '❌ NO'}"
    puts "Checked patterns: #{patterns.join(', ')}"
    puts ""

    # Check the language config first
    if has_language_config
      puts "🎯 FOUND: Language configuration cached!"
      puts "📄 directus/language_config"

      begin
        cached_data = Rails.cache.read('directus/language_config')
        if cached_data.is_a?(Array)
          puts "   📋 Array of #{cached_data.length} languages:"
          cached_data.each do |lang|
            if lang.is_a?(Hash)
              code = lang['code'] || lang['languages_code']
              name = lang['name'] || lang['display_name']
              puts "      • #{code}: #{name}"
            else
              puts "      • #{lang.inspect}"
            end
          end
        elsif cached_data.is_a?(Hash)
          puts "   📄 Language configuration object:"
          puts "      🔧 Available locales: #{cached_data['available_locales']&.inspect || 'none'}"
          puts "      🗺️  Directus mapping: #{cached_data['directus_mapping']&.inspect || 'none'}"
          puts "      🎯 Default language: #{cached_data['default_language'] || 'none'}"
          puts ""

          # Show how many locales are configured
          available_locales = cached_data['available_locales']
          if available_locales.is_a?(Array) && available_locales.any?
            puts "   🌍 #{available_locales.length} locales configured:"
            available_locales.each do |locale|
              directus_code = cached_data['directus_mapping']&.[](locale.to_sym) || cached_data['directus_mapping']&.[](locale.to_s)
              puts "      • #{locale} → #{directus_code || 'no mapping'}"
            end
          else
            puts "   ⚠️  No locales configured in cache"
          end
        else
          puts "   Cached data type: #{cached_data.class}"
          puts "   Content: #{cached_data.inspect[0..200]}..."
        end
      rescue => e
        puts "   Error reading language config: #{e.message}"
      end
      puts ""
    end

    if all_language_keys.empty?
      puts "❌ No individual language items cached with expected patterns"
      puts ""
      puts "🔍 Investigating further..."

      # Show ALL Directus cache keys to see what's actually cached
      all_directus = redis.keys('globalsymbols_cache:directus/*')
      puts ""
      puts "📊 ALL Directus cache keys (first 20):"
      all_directus.first(20).each do |key|
        clean_key = key.sub('globalsymbols_cache:', '')
        puts "   📄 #{clean_key}"
      end

      if all_directus.length > 20
        puts "   ... and #{all_directus.length - 20} more"
      end

      puts ""
      if has_language_config
        puts "💡 Languages are cached as a configuration object, not individual items"
        puts "💡 The website is reading from 'directus/language_config'"
      else
        puts "💡 Languages might be cached as collection lists, not individual items"
        puts "💡 Try: DirectusService.fetch_collection('languages')"
      end
      return
    end

    all_language_keys.each do |key|
      clean_key = key.sub('globalsymbols_cache:', '')
      puts "📄 #{clean_key}"

      # Try to read the cached data
      begin
        cached_data = Rails.cache.read(clean_key)
        if cached_data.is_a?(Hash) && cached_data['code']
          name = cached_data['name']
          code = cached_data['code']
          puts "   Code: #{code}, Name: #{name}"
        elsif cached_data.is_a?(Hash) && cached_data['data'].is_a?(Array)
          # Collection list of languages
          lang_count = cached_data['data'].length
          puts "   📋 Collection list: #{lang_count} languages"
          cached_data['data'].first(3).each do |lang|
            if lang.is_a?(Hash)
              puts "      • #{lang['code']}: #{lang['name']}"
            end
          end
          puts "      ... and #{lang_count - 3} more" if lang_count > 3
        else
          puts "   Cached data type: #{cached_data.class}"
        end
      rescue => e
        puts "   Error reading cache: #{e.message}"
      end
    end

    puts ""
    puts "🎯 Usage:"
    puts "  language_cached?('CODE')  # Check specific language"
    puts "  Rails.cache.clear          # Clear all cache"
  end

  # Inspect all Directus cache entries (collections + individual items)
  def inspect_all_directus_cache
    redis = Rails.cache.redis
    all_directus_keys = redis.keys('globalsymbols_cache:directus/*')

    puts "=== ALL DIRECTUS CACHE ENTRIES ==="
    puts "Total Directus cache entries: #{all_directus_keys.length}"
    puts ""

    if all_directus_keys.empty?
      puts "❌ No Directus data cached"
      return
    end

    # Group by type
    collections = {}
    all_directus_keys.each do |key|
      # Remove namespace
      clean_key = key.sub('globalsymbols_cache:directus/', '')

      # Extract collection/type
      parts = clean_key.split(':')
      collection = parts.first

      collections[collection] ||= []
      collections[collection] << clean_key
    end

    # Show summary by collection
    collections.each do |collection, keys|
      puts "📁 #{collection}: #{keys.length} entries"
      keys.first(3).each do |key|
        puts "   📄 #{key}"
      end
      puts "   ... and #{keys.length - 3} more" if keys.length > 3
      puts ""
    end
  end

  # Check cache for any collection (individual items only)
  def inspect_collection_cache(collection = 'articles')
    redis = Rails.cache.redis
    pattern = "globalsymbols_cache:directus/#{collection}:*"
    keys = redis.keys(pattern)

    puts "=== #{collection.upcase} CACHE INSPECTOR ==="
    puts "Total cached #{collection}: #{keys.length}"
    puts "Pattern: #{pattern}"
    puts ""

    if keys.empty?
      puts "❌ No #{collection} cached"
      return
    end

    keys.first(10).each do |key|  # Limit to first 10
      clean_key = key.sub('globalsymbols_cache:', '')
      puts "📄 #{clean_key}"
    end

    puts " ... and #{keys.length - 10} more" if keys.length > 10
  end

  # Check overall cache health
  def cache_health_check
    puts "=== CACHE HEALTH CHECK ==="

    # Test basic cache operations
    test_key = "health_check_#{Time.now.to_i}"
    test_value = "working_#{SecureRandom.hex(4)}"

    begin
      # Write test
      Rails.cache.write(test_key, test_value, expires_in: 5.minutes)
      puts "✅ Cache write: OK"

      # Read test
      read_value = Rails.cache.read(test_key)
      if read_value == test_value
        puts "✅ Cache read: OK"
      else
        puts "❌ Cache read: FAILED"
        return
      end

      # Delete test
      Rails.cache.delete(test_key)
      puts "✅ Cache delete: OK"

      # Redis connectivity
      redis = Rails.cache.redis
      info = redis.info rescue nil
      if info
        puts "✅ Redis connection: OK (DB #{redis.connection[:db]})"
        puts "📊 Redis keys: #{redis.dbsize}"
      else
        puts "❌ Redis connection: FAILED"
      end

      # Directus cache count
      directus_keys = redis.keys('globalsymbols_cache:directus/*')
      puts "📦 Directus cached items: #{directus_keys.length}"

      puts ""
      puts "🎉 Cache is healthy!"

    rescue => e
      puts "❌ Cache health check failed: #{e.message}"
    end
  end

  # Performance test
  def cache_performance_test(article_id = 4, language = 'en-GB')
    require 'benchmark'

    puts "=== CACHE PERFORMANCE TEST ==="
    puts "Article ID: #{article_id}, Language: #{language}"
    puts ""

    # Check if cached first
    cached_before = article_cached?(article_id, language)
    puts ""

    times = []

    Benchmark.bm do |x|
      x.report("API Call:") do
        article = DirectusService.fetch_item_with_translations('articles', article_id, language)
        times << [:api, article]
      end

      x.report("Cache Hit:") do
        article = DirectusService.fetch_item_with_translations('articles', article_id, language)
        times << [:cache, article]
      end
    end

    puts ""
    api_time, cache_time = times

    if api_time[1] && cache_time[1]
      speedup = (api_time[0] / cache_time[0]).round(1)
      puts "🚀 Cache speedup: #{speedup}x faster"
      puts "📊 API: #{api_time[0].round(4)}s, Cache: #{cache_time[0].round(4)}s"
    end
  end

  # Clear specific article from cache
  def clear_article_cache(id, language = 'en-GB')
    translation_params = DirectusService.send(:build_translation_params, language, {})
    cache_key = DirectusService.send(:build_cache_key, :get, "items/articles/#{id}", translation_params)

    result = Rails.cache.delete(cache_key)
    puts "🗑️  Cleared article #{id} (#{language}) from cache: #{result ? '✅ Success' : '❌ Not found'}"
    result
  end

  # Debug cache key generation for specific article
  def debug_article_cache_key(id, language = 'en-GB')
    puts "=== CACHE KEY DEBUG FOR ARTICLE #{id} (#{language}) ==="

    # Build translation params
    translation_params = DirectusService.send(:build_translation_params, language, {})
    puts "Translation params: #{translation_params.inspect}"

    # Build cache key
    cache_key = DirectusService.send(:build_cache_key, :get, "items/articles/#{id}", translation_params)
    puts "Generated cache key: #{cache_key}"

    # Check what Rails cache stores it as
    full_redis_key = "globalsymbols_cache:#{cache_key}"
    puts "Full Redis key: #{full_redis_key}"

    # Check if it exists
    redis = Rails.cache.redis
    exists = redis.exists(full_redis_key)
    puts "Key exists in Redis: #{exists ? 'YES' : 'NO'} (#{full_redis_key})"

    # Get raw Redis data if key exists
    if exists
      raw_redis_data = redis.get(full_redis_key)
      puts "Raw Redis data length: #{raw_redis_data&.length || 0} bytes"
      puts "Raw Redis data type: #{raw_redis_data.class}"

      if raw_redis_data.nil? || raw_redis_data.empty?
        puts "❌ PROBLEM FOUND: Redis key exists but contains no data!"
        puts "This is a corrupted/expired cache entry."
        puts ""
        puts "🛠️  SOLUTION: Clear this corrupted cache entry"
        puts "Run: CacheInspector.clear_article_cache(#{id}, '#{language}')"
        return
      end

      puts "Raw Redis data preview: #{raw_redis_data.first(200)}..." if raw_redis_data
    end

    # Try to read it via Rails cache
    cached_data = Rails.cache.read(cache_key)
    puts "Rails.cache.read result: #{cached_data.present? ? 'FOUND' : 'NOT FOUND'}"

    if cached_data
      puts "Cached data type: #{cached_data.class}"
      if cached_data.is_a?(Hash)
        puts "Cached article ID: #{cached_data['id']}"
        puts "Cached data keys: #{cached_data.keys.inspect}"
      end
    else
      puts "Cached data is nil/empty"
    end

    puts ""
    puts "🎯 Summary:"
    puts "  Article #{id} (#{language}) is #{cached_data.present? ? 'CACHED' : 'NOT CACHED'}"
  end

  # Clean up corrupted/empty cache entries
  def cleanup_empty_cache_entries
    puts "=== CLEANUP EMPTY CACHE ENTRIES ==="
    puts "This removes only truly empty/corrupted Redis entries"
    puts ""

    redis = Rails.cache.redis
    pattern = "globalsymbols_cache:directus/*"

    puts "Scanning for Directus cache keys..."
    keys = redis.keys(pattern)
    puts "Found #{keys.length} Directus cache keys"

    empty_keys = []
    valid_keys = []
    sample_valid = nil

    keys.each do |key|
      raw_data = redis.get(key)
      if raw_data.nil? || raw_data.empty?
        empty_keys << key
      else
        valid_keys << key
        # Store one sample for verification
        sample_valid ||= [key, raw_data]
      end
    end

    puts ""
    puts "📊 Analysis Results:"
    puts "Empty/corrupted keys: #{empty_keys.length}"
    puts "Valid keys: #{valid_keys.length}"

    # Verify sample valid entry can be read by Rails
    if sample_valid
      sample_key, sample_data = sample_valid
      cache_key = sample_key.sub('globalsymbols_cache:', '')
      begin
        rails_data = Rails.cache.read(cache_key)
        puts "✅ Sample valid entry readable by Rails: #{rails_data ? 'YES' : 'NO'}"
      rescue => e
        puts "⚠️  Sample valid entry has Rails read error: #{e.message}"
      end
    end

    if empty_keys.any?
      puts ""
      puts "🗑️  Removing empty cache entries..."
      puts "These are entries with nil/empty data at Redis level"
      removed = 0

      empty_keys.each do |key|
        # Remove the namespace prefix for Rails cache delete
        cache_key = key.sub('globalsymbols_cache:', '')
        Rails.cache.delete(cache_key)
        removed += 1
        print "."
      end

      puts ""
      puts "✅ Removed #{removed} empty cache entries"
      puts "Note: These were truly empty - not different data formats"
    else
      puts ""
      puts "✅ No empty cache entries found"
      puts "All cache entries contain valid data (may have different formats)"
    end

    puts ""
    puts "📊 After cleanup:"
    remaining_keys = redis.keys(pattern)
    puts "Remaining Directus keys: #{remaining_keys.length}"
  end

  # Quick status
  def cache_status
    redis = Rails.cache.redis
    directus_keys = redis.keys('globalsymbols_cache:directus/*')
    total_keys = redis.keys('globalsymbols_cache:*').length

    puts "📊 Cache Status:"
    puts "  Total keys: #{total_keys}"
    puts "  Directus items: #{directus_keys.length}"
    puts "  Articles cached: #{directus_keys.grep(/articles/).length}"
    puts "  Redis DB: #{redis.connection[:db]}"

    # Analyze cache contents
    individual_articles = []
    collection_lists = []
    total_unique_articles = Set.new

    directus_keys.select { |k| k.include?('articles') }.each do |key|
      begin
        clean_key = key.sub('globalsymbols_cache:', '')
        data = Rails.cache.read(clean_key)
        if data.is_a?(Hash) && data['data'].is_a?(Array)
          # Collection list cache
          list_size = data['data'].length
          collection_lists << list_size

          # Extract IDs from collection list
          first_item = data['data'].first
          if first_item.is_a?(Hash)
            data['data'].each { |article| total_unique_articles.add(article['id']) if article['id'] }
          elsif first_item.is_a?(Integer)
            data['data'].each { |id| total_unique_articles.add(id) }
          end
        elsif data.is_a?(Hash) && data['id']
          # Individual article cache
          individual_articles << data['id']
          total_unique_articles.add(data['id'])
        end
      rescue => e
        # Skip corrupted entries
      end
    end

    if individual_articles.any? || collection_lists.any?
      puts "  📄 Individual articles: #{individual_articles.length} (IDs: #{individual_articles.sort.inspect})"
      puts "  📋 Collection lists: #{collection_lists.length} (sizes: #{collection_lists.inspect})"
      puts "  🎯 Total unique articles available: #{total_unique_articles.length} (IDs: #{total_unique_articles.sort.to_a.inspect})"
    end
  end

  # Fetch and cache a specific article
  def fetch_and_cache_article(id, language = 'en-GB')
    puts "🔄 Fetching and caching article #{id} (#{language})..."

    begin
      article = DirectusService.fetch_item_with_translations('articles', id, language)
      if article
        puts "✅ Article #{id} fetched and cached"
        puts "   Title: #{article.dig('translations', 0, 'title')}"
        puts "   Status: #{article['status']}"

        # Verify it's now cached
        sleep 0.1 # Small delay to ensure caching
        cached = article_cached?(id, language)
        puts "   Verification: #{cached ? '✅ Now cached' : '❌ Still not cached'}"
      else
        puts "❌ Article #{id} not found in Directus"
      end
    rescue => e
      puts "❌ Error fetching article #{id}: #{e.message}"
    end
  end
end

# Auto-display help when loaded
if __FILE__ == $0
  puts "=== Directus Cache Inspector Loaded ==="
  puts ""
  puts "Available methods:"
  puts "  CacheInspector.inspect_article_cache          # Show all cached articles"
  puts "  CacheInspector.article_cached?(4, 'en-GB')   # Check specific article"
  puts "  CacheInspector.cache_health_check             # Test cache functionality"
  puts "  CacheInspector.cache_performance_test         # Benchmark cache vs API"
  puts "  CacheInspector.clear_article_cache(4)         # Clear specific article"
  puts "  CacheInspector.cache_status                    # Quick status summary"
  puts "  CacheInspector.inspect_collection_cache('articles') # Check any collection"
  puts ""
  puts "Usage in Rails console:"
  puts "  require 'cache_inspector'"
  puts "  inspect_article_cache"

  # Fetch and cache language configuration from Directus
  def fetch_and_cache_language(language_code)
    puts "=== FETCH LANGUAGE CONFIG FROM DIRECTUS ==="
    puts "Refreshing language configuration cache..."

    begin
      # Use LanguageConfigurationService to refresh the config
      success = LanguageConfigurationService.update_live_config

      if success
        puts "✅ Language configuration refreshed successfully"

        # Now check if the specific language is configured
        config = Rails.cache.read('directus/language_config')
        if config && config['available_locales']
          if config['available_locales'].include?(language_code.to_sym)
            puts "✅ Language #{language_code} is now configured"
            directus_code = config['directus_mapping']&.[](language_code.to_sym)
            puts "   Rails: #{language_code} → Directus: #{directus_code}"
          else
            puts "⚠️  Language #{language_code} not found in refreshed configuration"
            puts "   Available: #{config['available_locales'].inspect}"
          end
        end
      else
        puts "❌ Failed to refresh language configuration"
      end
    rescue => e
      puts "❌ Error refreshing language config: #{e.message}"
    end
  end

  # Check if a specific language is cached
  def check_language_cache(language_code)
    puts "=== CHECK LANGUAGE CACHE FOR #{language_code.upcase} ==="

    # Check the language config for mapping
    language_config = Rails.cache.read('directus/language_config')

    if language_config.is_a?(Hash)
      available_locales = language_config['available_locales'] || []
      directus_mapping = language_config['directus_mapping'] || {}

      # Check if this Rails locale is configured
      if available_locales.include?(language_code.to_sym) || available_locales.include?(language_code.to_s)
        directus_code = directus_mapping[language_code.to_sym] || directus_mapping[language_code.to_s]
        puts "Language #{language_code}: ✅ CONFIGURED"
        puts "  Rails locale: #{language_code}"
        puts "  Directus code: #{directus_code || 'no mapping'}"
        puts "  Default language: #{language_config['default_language'] == directus_code ? 'YES' : 'NO'}"
        return
      end
    end

    # Not found in configuration
    puts "Language #{language_code}: ❌ NOT CONFIGURED"
    puts "  This locale is not in the language configuration cache"
    puts "  💡 Try: fetch_lang #{language_code}"
  end
end
