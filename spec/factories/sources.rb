FactoryBot.define do
  factory :source do
    sequence(:name) {|n| "Source #{n}" }
    sequence(:slug) {|n| "source-#{n}" }
    authoritative { true }
  end
end
