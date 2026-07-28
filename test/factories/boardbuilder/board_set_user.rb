FactoryBot.define do
  factory :board_set_user, class: Boardbuilder::BoardSetUser do
    user
    association :board_set, factory: :board_set
    role { :owner }

    trait :editor do
      role { :editor }
    end
  end
end
