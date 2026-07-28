FactoryBot.define do
  factory :licence do
    sequence(:name) {|n| "All Rights Reserved #{n}.0" }
    
    trait :creative_commons do
      sequence(:name) {|n| "Creative Commons #{n}.0 TE ST" }
      sequence(:url) {|n| "http://creativecommons.org/licenses/te-st/#{n}.0/" }
      sequence(:version) {|n| "#{n}.0" }
      properties { "by" }
      logo { "Logo" }
    end
  end
  
  # Finds and returns a random licence from the DB. Licences are added in seeds.rb
  sequence(:random_licence) do
    Licence.offset(rand(Licence.count)).first
  end
end
