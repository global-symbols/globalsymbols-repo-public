# Directus Cache Inspector

A comprehensive tool for inspecting and managing your Directus caching system.

## 🚀 Quick Start

### Rails Console (Interactive)
```ruby
require 'cache_inspector'
inspect_article_cache
```

### Command Line (Interactive)
```bash
./bin/cache_inspector
```

### Rails Runner (One-off commands)
```bash
# Check cache status
rails runner "require 'cache_inspector'; CacheInspector.cache_status"

# Check specific article
rails runner "require 'cache_inspector'; CacheInspector.article_cached?(4, 'en-GB')"
```

## 📊 Available Methods

### Core Inspection
- `inspect_article_cache` - Show all cached articles with details
- `article_cached?(id, language)` - Check if specific article is cached
- `inspect_collection_cache(collection)` - Inspect any cached collection
- `cache_status` - Quick overview of cache state

### Health & Performance
- `cache_health_check` - Test cache read/write/delete functionality
- `cache_performance_test(id, language)` - Benchmark cache vs API performance

### Management
- `clear_article_cache(id, language)` - Remove specific article from cache
- `debug_article_cache_key(id, language)` - Debug cache key generation and lookup
- `fetch_and_cache_article(id, language)` - Fetch specific article from Directus and cache it
- `language_cached?(code)` - Check if specific language is cached
- `fetch_and_cache_language(code)` - Fetch specific language from Directus and cache it
- `inspect_cached_languages` - Show all cached languages
- `cleanup_empty_cache_entries` - Remove corrupted/empty cache entries

## 🎮 Interactive Mode Commands

When running `./bin/cache_inspector`:

```
cache> status          # Show cache overview
cache> inspect         # Show all cached articles
cache> check 4         # Check if article 4 is cached
cache> health          # Run health check
cache> perf 4          # Performance test for article 4
cache> check 4         # Check if article 4 is cached
cache> check_lang en-GB # Check if English language is cached
cache> clear 4         # Clear article 4 from cache
cache> debug 4         # Debug cache key for article 4
cache> fetch 4         # Fetch and cache article 4
cache> fetch_lang fr-FR # Fetch and cache French language
cache> articles        # Show only individual cached articles
cache> languages       # Show cached languages
cache> all             # Show ALL Directus cached data
cache> cleanup         # Remove empty/corrupted cache entries
cache> collections     # Show configured collections
cache> help            # Show all commands
cache> exit            # Quit
```

## 📋 Examples

### Check Cache Before Fetching
```ruby
require 'cache_inspector'

if CacheInspector.article_cached?(4, 'en-GB')
  puts "Article 4 is cached - safe to fetch"
  article = DirectusService.fetch_item_with_translations('articles', 4, 'en-GB')
else
  puts "Article 4 not cached - fetch will hit API"
end
```

### Understanding Cache Check Results
**Important:** The `check` command (`article_cached?`) searches **collection caches**, not individual article caches:

- ✅ **"CACHED (in collections)"** - Article exists in cached collection results + **shows full article details**
- ✅ **"CACHED (individual)"** - Article cached as individual item (rare) + shows details
- ❌ **"NOT CACHED"** - Article not found in any cache

**When cached, it displays:**
- Article ID, status, featured status
- Creation/update dates
- Author name, slug, categories
- Title, content preview, language
- Image information

Articles are typically cached as part of collections (like "get articles with limit 1000"), not individually. The check command finds articles within these collection caches and shows their complete details.

### Monitor Cache Changes
```ruby
require 'cache_inspector'

puts "Before webhook..."
CacheInspector.inspect_article_cache

# Simulate webhook
DirectusService.invalidate_collection!('articles')

puts "After webhook..."
CacheInspector.inspect_article_cache
```

### Performance Testing
```ruby
require 'cache_inspector'
CacheInspector.cache_performance_test(4, 'en-GB')
# Shows API call time vs cache hit time
```

## 🔧 Files Created

- `lib/cache_inspector.rb` - Core inspector module
- `bin/cache_inspector` - Interactive command-line tool
- `CACHE_INSPECTOR_README.md` - This documentation

## 🎯 Use Cases

- **Debug webhooks**: See what gets cached/uncached
- **Performance monitoring**: Compare API vs cache response times
- **Cache management**: Clear specific items when needed
- **Health checks**: Verify cache system is working
- **Development**: Inspect cache state during development

## ⚡ Pro Tips

- **Always check cache first**: Use `article_cached?()` before fetching to avoid unwanted API calls
- **Monitor after webhooks**: Check cache state changes after Directus updates
- **Performance testing**: Use the benchmark to see cache effectiveness
- **Interactive mode**: Use `./bin/cache_inspector` for quick checks

The inspector never makes API calls - it only reads from cache! 🔍

## 🚀 Getting Started

```bash
# First time setup
cd /your/rails/app

# Interactive mode
./bin/cache_inspector

## Language Commands

Languages in this system are stored as **configuration metadata**, not individual cached objects. The language config includes:

- **Available locales**: Rails locale symbols (e.g., `[:en, :fr]`)
- **Directus mapping**: Maps Rails codes to Directus codes (e.g., `{en: 'en-GB'}`)
- **Default language**: The default Directus language code

### Commands

- `languages` - Show cached language configuration from `directus/language_config`
- `check_lang CODE` - Check if Rails locale is configured (e.g., `check_lang en`)
- `fetch_lang CODE` - Refresh entire language configuration from Directus

### Examples

```bash
cache> languages
# Shows: Available locales, Directus mapping, default language, and locale list

cache> check_lang en
# Shows: Whether 'en' locale is configured and its Directus mapping

cache> fetch_lang en
# Refreshes the entire language configuration from Directus
```

# Rails Console Usage

# Or in Rails console
rails console
require 'cache_inspector'
inspect_article_cache
```
