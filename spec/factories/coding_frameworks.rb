FactoryBot.define do
  factory :coding_framework do
    sequence(:name) {|n| "Coding Framework #{n}" } # To generate unique names
    structure { 1 }
    api_uri_base { "http://api.conceptnet.io/c/%{language}/%{subject}" } # Validating against ConceptNet for now.
    www_uri_base { "http://www.conceptnet.io/c/%{language}/%{subject}" } # Validating against ConceptNet for now.
    
    trait :with_concepts do
      after :create do |ccf|
        FactoryBot.create_list(:concept, 3, coding_framework: ccf)
      end
    end
  end
end
