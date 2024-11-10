FactoryBot.define do
  factory :doorkeeper_token, class: 'Doorkeeper::AccessToken' do
    application_id { FactoryBot.create(:doorkeeper_application).id }
    resource_owner_id { FactoryBot.create(:user).id }
    scopes { :write }

    trait :with_boardbuilder_scopes do
      scopes { 'openid profile email boardset:read boardset:write' }
    end
  end
end