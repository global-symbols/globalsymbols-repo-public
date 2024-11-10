FactoryBot.define do
  factory :board, class: Boardbuilder::Board do
    association :board_set, factory: :board_set
    sequence(:name) {|n| "Board #{n}" }
    sequence(:index) {|n| n }
    columns { 2 }
    rows { 2 }
    captions_position { 'below' }

  end
end