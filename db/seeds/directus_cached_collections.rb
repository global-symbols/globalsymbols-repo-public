# frozen_string_literal: true

# Directus Cached Collections Seed
# This file seeds the initial Directus cached collections configuration
# Run with: rails runner db/seeds/directus_cached_collections.rb

puts "🌱 Seeding Directus cached collections..."

# Articles collection - the primary content collection
DirectusCachedCollection.find_or_create_by!(name: 'articles') do |collection|
  collection.parameter_sets = [
    # Used by articles index - matches build_translation_params + limit: 1000
    {
      'fields' => 'id,status,featured,slug,author.first_name,author.last_name,date_created,date_updated,publish_date,image,categories.article_categories_id.name,categories.article_categories_id.id,translations.title,translations.content,translations.short_description,translations.gs_languages_code',
      'filter' => { 'status' => { '_eq' => 'published' } },
      'limit' => 1000
    },
    # Used for smaller article lists - matches build_translation_params + limit: 9
    {
      'fields' => 'id,status,featured,slug,author.first_name,author.last_name,date_created,date_updated,publish_date,image,categories.article_categories_id.name,categories.article_categories_id.id,translations.title,translations.content,translations.short_description,translations.gs_languages_code',
      'filter' => { 'status' => { '_eq' => 'published' } },
      'limit' => 9
    },
    # Used by articles show - matches build_translation_params + slug filter
    # Note: We can't cache specific slugs, but we can cache the pattern for show pages
    {
      'fields' => 'id,status,featured,slug,author.first_name,author.last_name,date_created,date_updated,publish_date,image,categories.article_categories_id.name,categories.article_categories_id.id,translations.title,translations.content,translations.short_description,translations.gs_languages_code',
      'filter' => { 'status' => { '_eq' => 'published' } },
      'limit' => 1
    }
  ]
  collection.priority = 10
  collection.description = 'News articles and blog posts'
  collection.active = true
end

# Boardsets collection - Tap Topics
DirectusCachedCollection.find_or_create_by!(name: 'boardsets') do |collection|
  collection.parameter_sets = [
    {
      'fields' => 'id,status,date_created,date_updated,board_low,board_high,thumbnail,categories.boardset_categories_id.name,categories.boardset_categories_id.id,translations.title,translations.gs_languages_code',
      'filter' => { 'status' => { '_eq' => 'published' } },
      'limit' => 1000
    }
  ]
  collection.priority = 9
  collection.description = 'Tap Topics boardsets'
  collection.active = true
end

puts "✅ Directus cached collections seeded successfully!"
puts "📊 Current collections: #{DirectusCachedCollection.cached_collection_names.inspect}"
