FactoryBot.define do
  factory :symbolset_user do
    user
    symbolset
    trait :admin do
      role { :admin }
    end
  end
end
