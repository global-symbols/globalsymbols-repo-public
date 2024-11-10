require 'rails_helper'

RSpec.describe GlobalSymbols::V1::Languages, type: :request do
  # Languages are loaded in seeds, so there's no need to create with FactoryBot.
  context 'GET /api/v1/languages/active' do
    it 'returns an array of active languages' do
      get '/api/v1/languages/active'
      
      expect(response.status).to eq(200)

      # Every active Language should be in the response.body
      Language.where(active: true).each do |language|
        expect(response.body).to include language.id.to_s, language.iso639_3
      end
    end

    it 'does not return in-active languages' do
      get '/api/v1/languages/active'
  
      expect(response.status).to eq(200)
      
      inactive_language = Language.find_by(active: false)
      expect(response.body).to_not include inactive_language.id.to_s, inactive_language.iso639_3
    end
  end
end