require 'rails_helper'

RSpec.describe GlobalSymbols::V1::Symbolsets, type: :request do
  context 'GET /api/v1/symbolsets' do
    it 'returns an array of published Symbolsets' do
      symbolset = FactoryBot.create(:symbolset, :published)
      
      get '/api/v1/symbolsets'
      
      expect(response.status).to eq(200)
      
      expect(response.body).to include symbolset.name
      
      expect(JSON.parse(response.body).count).to eq 1
    end
    
    it 'orders Symbolsets by a value in featured_level, then name' do
      FactoryBot.create(:symbolset, :published, name: 'y f2', featured_level: 2)
      FactoryBot.create(:symbolset, :published, name: 'a f-', featured_level: nil)
      FactoryBot.create(:symbolset, :published, name: 'z f1', featured_level: 1)
      FactoryBot.create(:symbolset, :published, name: 'm f1', featured_level: 1)

      get '/api/v1/symbolsets'
      
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json.pluck('name')).to eq ['m f1', 'y f2', 'z f1', 'a f-']
    end
    
    it 'does not return non-published Symbolsets' do
      unpublished_symbolset = FactoryBot.create(:symbolset)
      published_symbolset = FactoryBot.create(:symbolset, :published)
  
      get '/api/v1/symbolsets'
      
      expect(JSON.parse(response.body).count).to eq 1
      
      expect(response.body).to_not include unpublished_symbolset.name
      expect(response.body).to include published_symbolset.name
    end
  end
end