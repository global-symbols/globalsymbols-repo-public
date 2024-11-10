FactoryBot.define do
  factory :user do
    prename { 'Joe' }
    surname { 'Bloggs' }
    language { Language.find_by!(iso639_1: :en) }
    
    sequence(:email) {|n| "user#{n}@test.com" } # To generate unique email addresses
    password { 'password' }

    trait :admin do
      sequence(:email) {|n| "admin#{n}@test.com" }
      role { :admin }
    end

    trait :with_boardbuilder_auth_token do
      after :create do |user, e|
        user.access_tokens << FactoryBot.create(:doorkeeper_token, scopes: 'openid profile email boardset:read boardset:write')
      end
    end
    
    transient do
      comments_count { 0 }
    end
    
    after :create do |user, e|
      user.comments << FactoryBot.create_list(:comment, e.comments_count)
    end
  end
end
