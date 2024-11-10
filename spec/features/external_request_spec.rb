require 'rails_helper'

RSpec.describe "External Requests" do
  feature 'External request' do
    it 'Fails when querying FactoryBot contributors on GitHub' do
      uri = URI('https://api.github.com/repos/thoughtbot/factory_girl/contributors')
      expect{Net::HTTP.get(uri)}.to raise_exception WebMock::NetConnectNotAllowedError
    end
  end
end