require 'rails_helper'

RSpec.describe GlobalSymbols::V1::User, type: :request do
  context 'GET /api/v1/user' do
    it 'returns the authenticated user for a bearer token without requiring an API key' do
      access_token = FactoryBot.create(:doorkeeper_token, scopes: 'profile')
      user = User.find(access_token.resource_owner_id)

      get '/api/v1/user', headers: { 'Authorization' => "Bearer #{access_token.token}" }

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body)).to include(user.slice('id', 'prename', 'surname'))
    end
  end
end
