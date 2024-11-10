# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

# Licences
cc_licence_types = [ 'by', 'by-sa', 'by-nd', 'by-nc', 'by-nc-sa', 'by-nc-nd' ]
cc_licence_types.each do |licence|
  Licence.create_with(
      version: '4.0',
      properties: licence
  ).find_or_create_by!(
    name: "Creative Commons #{licence.gsub('-',' ').upcase} 4.0",
    url: "https://creativecommons.org/licenses/#{licence}/4.0/",
  )
end
Licence.find_or_create_by!(name: 'All Rights Reserved')
Licence.find_or_create_by!(name: 'Public Domain')

# Coding Frameworks
CodingFramework.create(
    name: 'ConceptNet',
    structure: :linked_data,
    api_uri_base: 'http://api.conceptnet.io/c/%{language}/%{subject}',
    www_uri_base: 'http://www.conceptnet.io/c/%{language}/%{subject}'
)

# Sources for Pictos and Labels
Source.create(name: 'Publisher API', slug: 'api', authoritative: true)
Source.create(name: 'Publisher Repository', slug: 'repo', authoritative: true)
Source.create(name: 'Global Symbols', slug: 'global-symbols', authoritative: true)

Source.create(name: 'Translation', slug: 'translation', authoritative: true, suggestion: false)
Source.create(name: 'Translation Suggestion', slug: 'translation-suggestion', authoritative: false, suggestion: true)
Source.create(name: 'Public Suggestion', slug: 'public-suggestion', authoritative: false, suggestion: true)

# Languages
ImportLanguagesJob.perform_now

if Rails.env == 'development'
  require 'factory_bot_rails'
  
  FactoryBot.create_list(:user, 2, :admin)
  FactoryBot.create_list(:user, 10)
  
  FactoryBot.create_list(:symbolset, 10)
  Symbolset.limit(5).update_all(status: :published)
  
  Symbolset.all.each do |symbolset|
    # Add 20-40 symbols to each symbolset
    FactoryBot.create_list(:picto, rand(20...40), :with_concepts, symbolset: symbolset)
    
    # Associate 1-3 users with each symbolset
    User.all.where.not(id: symbolset.users.ids).order('RAND()').limit(rand(1...3)).each_with_index do |user, index|
      # The first user should be an admin on the symbolset
      trait = index == 0 ? :admin : nil
      FactoryBot.create(:symbolset_user, trait, symbolset: symbolset, user: user)
    end
  end
end
