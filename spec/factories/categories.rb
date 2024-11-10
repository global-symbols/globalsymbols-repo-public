FactoryBot.define do
  factory :category do
    sequence(:name) {|n| "Food #{n}.0" }
    concept
  end
  
  trait :with_pictos do
    after :create do |category|
      category.pictos << FactoryBot.create_list(:picto, 3)
    end
  end
end