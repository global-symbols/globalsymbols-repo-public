# Database Seeds

This directory contains individual seed files for different data types.

## Available Seed Files

### `directus_cached_collections.rb`
Seeds the Directus cached collections configuration.

**Usage:**
```bash
# Run just the Directus cached collections seed
rails runner db/seeds/directus_cached_collections.rb

# Or run all seeds (includes this one)
rails db:seed
```

**What it does:**
- Creates/updates the 'articles' collection with proper parameter sets
- Sets priority and description for cache warming operations
- Enables the collection for webhook processing

## Adding New Collections

To add new Directus collections, edit `directus_cached_collections.rb` and add:

```ruby
DirectusCachedCollection.find_or_create_by!(name: 'your_collection_name') do |collection|
  collection.parameter_sets = [
    { 'limit' => 500 },
    # Add your parameter sets here
  ]
  collection.priority = 5  # Higher numbers = higher priority
  collection.description = 'Description of your collection'
  collection.active = true
end
```

Then run the seed file to apply changes.
