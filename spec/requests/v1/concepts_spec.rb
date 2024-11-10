require 'rails_helper'

RSpec.describe GlobalSymbols::V1::Concepts, type: :request do
  context 'GET /api/v1/concepts/suggest' do
    
    it 'returns an array of suggestions' do
      concept1 = FactoryBot.create(:concept, subject: 'fresh fruit now')
      concept2 = FactoryBot.create(:concept, subject: 'rotten fruit now')
      
      get '/api/v1/concepts/suggest', params: { query: 'fruit now' }
      
      expect(response.status).to eq(200)
      
      expect(response.body).to include concept1.subject
      expect(response.body).to include concept2.subject
      
      expect(JSON.parse(response.body).count).to eq 2
    end
    
    it 'returns correct results for queries in Arabic' do
      food = 'أكل'
      airplane = 'طائرة'
      
      arabic = Language.find_by(iso639_3: 'ara')
      
      symbolset = FactoryBot.create(:symbolset, :with_pictos, pictos_count: 2)
      
      airplane_concept = FactoryBot.create(:concept, subject: airplane, language: arabic)
      food_concept = FactoryBot.create(:concept, subject: food, language: arabic)

      symbolset.pictos.first.concepts << airplane_concept
      symbolset.pictos.second.concepts << food_concept
    
      get '/api/v1/concepts/suggest', params: { query: food, language: arabic.iso639_3 }
      
      expect(response.body).to include food
      expect(response.body).to_not include airplane
    end

    it 'returns results from a specific symbolset' do
      # Create two Symbolsets. We want to see only one of them in the results.
      symbolset1 = FactoryBot.create(:symbolset, :with_pictos, :published)
      symbolset2 = FactoryBot.create(:symbolset, :with_pictos, :published)
      
      # Create two Concepts, both of which will be found with the search string 'example'.
      concept = FactoryBot.create(:concept, subject: 'good')
      
      # Add the Concept to Pictos on both Symbolsets
      symbolset1.pictos.first.concepts << concept
      symbolset2.pictos.first.concepts << concept
      
      # Request suggestions for 'example' within symbolset1
      get '/api/v1/concepts/suggest', params: { query: 'good', symbolset: symbolset1.slug }
      
      expect(response.status).to eq(200)
      
      # Suggestions should contain the first picto from symbolset1, but not from symbolset2
      expect(response.body).to include symbolset1.pictos.first.id.to_s
      expect(response.body).to_not include symbolset2.pictos.first.id.to_s
    end

    it 'returns HTTP 400 when filtering on an un-published Symbolset' do
      symbolset = FactoryBot.create(:symbolset, :with_pictos, status: :draft)
      
      concept = FactoryBot.create(:concept, subject: 'example')
      
      symbolset.pictos.first.concepts << concept
      
      get '/api/v1/concepts/suggest', params: { query: 'example', symbolset: symbolset.slug }
      
      expect(response.status).to eq(400)
      
      expect(response.body).to_not include concept.subject
      expect(response.body).to_not include symbolset.name
    end
    
    it 'does not expose pictos from un-published Symbolsets' do
      symbolset = FactoryBot.create(:symbolset, :with_pictos, status: :draft)
      
      concept = FactoryBot.create(:concept, subject: 'example')
      
      symbolset.pictos.first.concepts << concept
      
      get '/api/v1/concepts/suggest', params: { query: 'example' }
  
      expect(response.status).to eq(200)
      
      expect(response.body).to_not include symbolset.name
      expect(response.body).to_not include symbolset.pictos.first.id.to_s
      expect(JSON.parse(response.body).first['pictos'].count).to eq 0
    end
    
    it 'applies a limit to the number of results' do
      FactoryBot.create(:concept, subject: 'good dog')
      FactoryBot.create(:concept, subject: 'good boy')
      FactoryBot.create(:concept, subject: 'good girl')
      
      get '/api/v1/concepts/suggest', params: { query: 'good', limit: 1 }
      expect(JSON.parse(response.body).count).to eq 1
    end

    it 'returns results from a specific language' do
      concept1 = FactoryBot.create(:concept, language: FactoryBot.create(:language), subject: 'good')
      concept2 = FactoryBot.create(:concept, language: FactoryBot.create(:language), subject: 'bon')
      expect(concept1.language.iso639_1).to_not eq concept2.language.iso639_1
      
      get '/api/v1/concepts/suggest', params: { query: 'good', language: concept1.language.iso639_3 }
      
      expect(response.status).to eq 200
      expect(JSON.parse(response.body).count).to eq 1
      expect(response.body).to include concept1.subject
      expect(response.body).to_not include concept2.subject
    end
    
    it 'searches using ISO639_3 codes by default' do
      concept1 = FactoryBot.create(:concept, language: FactoryBot.create(:language), subject: 'good')
      get '/api/v1/concepts/suggest', params: { query: 'good', language: concept1.language.iso639_3 }
      expect(response.status).to eq 200
      expect(JSON.parse(response.body).count).to eq 1
      expect(response.body).to include concept1.subject
    end

    it 'searches using other ISO639 codes when specified' do
      concept1 = FactoryBot.create(:concept, language: FactoryBot.create(:language), subject: 'good')
      get '/api/v1/concepts/suggest', params: { query: 'good', language: concept1.language.iso639_1, language_iso_format: '639-1' }
      expect(response.status).to eq 200
      expect(JSON.parse(response.body).count).to eq 1
      expect(response.body).to include concept1.subject
    end
    
    it "returns concepts ordered by whole word match first" do
      # Create the Concepts in the wrong ordering
      dogmatic      = FactoryBot.create(:concept, subject: 'dogmatic')
      dog           = FactoryBot.create(:concept, subject: 'dog')
      boondoggle    = FactoryBot.create(:concept, subject: 'boondoggle')
      seadog        = FactoryBot.create(:concept, subject: 'seadog')
      top_dog       = FactoryBot.create(:concept, subject: 'top_dog')
      dog_days      = FactoryBot.create(:concept, subject: 'dog_days')
      my_dog_smells = FactoryBot.create(:concept, subject: 'my_dog_smells')

      get '/api/v1/concepts/suggest', params: { query: 'dog' }

      json = JSON.parse(response.body)

      # Check the labels have been re-ordered correctly.
      expect(json[0]['subject']).to eq dog.subject           # whole word
      expect(json[1]['subject']).to eq dog_days.subject      # phrase start whole word
      expect(json[2]['subject']).to eq top_dog.subject       # phrase end whole word
      expect(json[3]['subject']).to eq my_dog_smells.subject # within phrase whole word
      expect(json[4]['subject']).to eq dogmatic.subject      # phrase start part of a word
      expect(json[5]['subject']).to eq seadog.subject        # phrase end part of a word
      expect(json[6]['subject']).to eq boondoggle.subject    # within phrase, part of a word
    end
    
    it 'returns 400 for requests with no query param' do
      get '/api/v1/concepts/suggest'
      expect(response.status).to eq(400)
    end
  end

  context 'GET /api/v1/concepts/{id}' do

    context 'for a missing Concept' do
      it 'returns 404' do
        get '/api/v1/concepts/94'
        expect(response.status).to eq(404)
      end
    end

    context 'for an existing Concept' do
      it 'returns the Concept' do
        concept = FactoryBot.create(:concept)
    
        get "/api/v1/concepts/#{concept.id}"
        expect(response.status).to eq 200
        expect(response.body).to include concept.id.to_s
        expect(response.body).to include concept.subject
      end
    end
  end
end