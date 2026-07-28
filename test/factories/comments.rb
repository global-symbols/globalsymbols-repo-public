FactoryBot.define do
  factory :comment do
    picto
    user
    rating { Random.rand(1..5) }
    comment { 'This is a comment.' }
    read { false }
    resolved { false }
    
    trait :with_survey_response do
      survey_response
    end
    
    trait :with_all_ratings do
      representation_rating { Random.rand(1..5) }
      contrast_rating { Random.rand(1..5) }
      cultural_rating { Random.rand(1..5) }
    end
  end
end