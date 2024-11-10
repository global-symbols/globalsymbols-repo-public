FactoryBot.define do
  factory :symbolset do
    licence { Licence.first! }
    sequence(:name) {|n| "Symbol Set #{n}" } # To generate unique names
    description { 'Test description' }
    publisher { 'Test Publisher' }
    status { :draft }
    
    transient do
      users_count { 1 }
      pictos_count { 1 }
    end
    
    after :build do |symbolset, e|
      symbolset.symbolset_users << FactoryBot.build_list(:symbolset_user, e.users_count, symbolset: symbolset)
    end
    
    trait :published do
      # Symbolsets must be draft when created, hence the after :create
      after :create do |symbolset|
        symbolset.update(status: :published)
      end
    end
    
    trait :with_pictos do
      after :create do |symbolset, e|
        symbolset.pictos << FactoryBot.create_list(:picto, e.pictos_count, symbolset_id: symbolset.id)
      end
    end
  end
end
