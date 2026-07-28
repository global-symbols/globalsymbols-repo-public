FactoryBot.define do
  factory :survey_picto do
    transient do
      symbolset { FactoryBot.create :symbolset }
    end
    survey { FactoryBot.create :survey, symbolset: symbolset }
    picto { FactoryBot.create :picto, symbolset: symbolset }
  end
end
