# frozen_string_literal: true

# Directus Cached Collections Seed
# This file seeds the initial Directus cached collections configuration
# Run with: rails runner db/seeds/directus_cached_collections.rb

puts "🌱 Seeding Directus cached collections..."

# Articles collection - the primary content collection
DirectusCachedCollection.find_or_create_by!(name: 'articles') do |collection|
  collection.parameter_sets = [
    { 'limit' => 1000 },  # Used by articles index for pagination/filtering
    { 'limit' => 9 }      # Used for featured articles or small lists
  ]
  collection.priority = 10
  collection.description = 'News articles and blog posts'
  collection.active = true
end

puts "✅ Directus cached collections seeded successfully!"
puts "📊 Current collections: #{DirectusCachedCollection.cached_collection_names.inspect}"
