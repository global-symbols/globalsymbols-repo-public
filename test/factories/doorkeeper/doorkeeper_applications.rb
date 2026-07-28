FactoryBot.define do
  factory :doorkeeper_application, class: 'Doorkeeper::Application' do
    sequence(:name) {|n| "application-#{n}" }
    redirect_uri {'https://app.com'}
  end
end