FactoryBot.define do
  factory :label do
    picto
    source
    language { Language.find_by(iso639_1: :en) }
    sequence(:text) { |n| n }
    description { 'This symbol is a ...' }
  end
end