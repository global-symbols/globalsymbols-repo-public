FactoryBot.define do
  factory :concept do
    coding_framework { CodingFramework.first }
    language { Language.find_by(iso639_1: :en) }
    # To generate unique subjects. Using plain numbers so there's a good chance they'll
    # correspond to a Concept on ConceptNet. However, this isn't guaranteed, and
    # ConceptNet appears have numbers up to 100.
    sequence(:subject) {|n| n }

    trait :with_pictos do
      after :create do |concept|
        concept.pictos << FactoryBot.create_list(:picto, 3)
      end
    end
  end
end
