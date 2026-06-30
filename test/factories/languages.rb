FactoryBot.define do
  factory :language do
    active { true }
    macrolanguage { nil }
    sequence(:name) {|n| "Language #{n}" }
    scope { "I" }
    category { "L" }
    
    # Language codes should be unique throughout all code types.
    # e.g. We cannot have iso639_1 set to 'aa' AND iso639_3 set to 'aa'
    sequence(:iso639_3) {|n| "3#{n}" }
    sequence(:iso639_2b) {|n| "b#{n}" }
    sequence(:iso639_2t) {|n| "t#{n}" }
    sequence(:iso639_1) {|n| n }

    factory :macrolanguage do
      macrolanguage { nil }
      sequence(:name) {|n| "Macrolanguage #{n}" }
      scope { "M" }

      trait :with_individual_languages do
        after :create do |macrolanguage|
          FactoryBot.create_list(:individual_language, 5,
                                 macrolanguage: macrolanguage
          )
        end
      end
    end
    
    factory :individual_language do
      sequence(:name) {|n| "#{macrolanguage.name} Child #{n}" }
      iso639_2b { nil }
      iso639_2t { nil }
      iso639_1 { nil }
    end
  end
end
