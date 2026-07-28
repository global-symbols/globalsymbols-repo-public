FactoryBot.define do
  factory :cell, class: Boardbuilder::Cell do
    association :board, factory: :board
    sequence(:caption) {|n| "Cell #{n}" }
    # sequence(:index) {|n| n }
  end
end