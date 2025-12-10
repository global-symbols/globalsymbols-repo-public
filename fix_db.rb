#!/usr/bin/env ruby
# Fix Directus cached collections to use gs_languages_code
require 'bundler/setup'
require 'rails'
require_relative 'config/environment'

puts "🔧 Fixing Directus cached collections database..."

collection = DirectusCachedCollection.find_by(name: 'articles')
if collection
  puts "📊 Found articles collection with #{collection.parameter_sets.length} parameter sets"

  collection.parameter_sets.each_with_index do |params, index|
    if params['fields'] && params['fields'].include?('translations.languages_code')
      old_fields = params['fields'].dup
      params['fields'] = params['fields'].gsub('translations.languages_code', 'translations.gs_languages_code')
      puts "  ✅ Updated parameter set #{index + 1}:"
      puts "    Old: #{old_fields}"
      puts "    New: #{params['fields']}"
    else
      puts "  ℹ️  Parameter set #{index + 1} already correct"
    end
  end

  if collection.changed?
    collection.save!
    puts "💾 Changes saved to database"
  else
    puts "ℹ️  No changes needed"
  end
else
  puts "❌ Articles collection not found in database"
end

puts "🎯 Database fix complete"
