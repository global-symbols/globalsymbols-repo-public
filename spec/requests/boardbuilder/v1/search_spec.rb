require 'rails_helper'

RSpec.describe BoardBuilder::V1::Search, type: :request do
  context 'GET /api/boardbuilder/v1/symbols/search' do
    
    it 'returns an array of suggestions' do
      get '/api/boardbuilder/v1/symbols/search', params: { query: 'dog', source: 'the-noun-project' }
      
      expect(response.status).to eq(200)
      
      # pp JSON.parse(response.body)
      
      expect(response.body).to include 'Dog'
      expect(response.body).to_not include 'Cat'
    end
  end

end
