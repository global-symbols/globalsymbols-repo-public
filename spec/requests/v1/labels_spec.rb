require 'rails_helper'

RSpec.describe GlobalSymbols::V1::Labels, type: :request do
  context 'GET /api/v1/labels/search' do
    
    it 'returns an array of suggestions' do
      picto1 = FactoryBot.create(:picto, :with_published_symbolset)
      picto2 = FactoryBot.create(:picto, :with_published_symbolset)
      
      picto1.labels.first.update(text: 'fresh fruit now')
      picto2.labels.first.update(text: 'fresh fruit now')
      
      get '/api/v1/labels/search', params: { query: 'fruit now' }

      pp response.body
      
      expect(response.status).to eq(200)
      
      expect(response.body).to include picto1.labels.first.text
      expect(response.body).to include picto2.labels.first.text
      
      expect(JSON.parse(response.body).count).to eq 2
    end
    
    it 'returns correct results for queries in Arabic' do
      food = 'أكل'
      airplane = 'طائرة'
      
      arabic = Language.find_by(iso639_3: 'ara')

      picto1 = FactoryBot.create(:picto, :with_published_symbolset)
      picto2 = FactoryBot.create(:picto, :with_published_symbolset)

      picto1.labels.first.update(text: food, language: arabic)
      picto2.labels.first.update(text: airplane, language: arabic)
    
      get '/api/v1/labels/search', params: { query: food, language: arabic.iso639_3 }
      
      expect(response.status).to eq 200
      expect(response.body).to include food
      expect(response.body).to_not include airplane
    end

    context 'with Latin and Cyrillic symbols' do
      before :each do
        @serbo_croat = Language.find_by!(iso639_3: 'srp')
        @car_cyrl = 'аутомобил'
        @car_latn = 'automobil'
  
        @picto = FactoryBot.create(:picto, :with_published_symbolset)
        @picto.labels.first.update!(text: @car_cyrl, language: @serbo_croat)
        FactoryBot.create(:label, picto: @picto, text: @car_latn, language: @serbo_croat)
        
        expect(@picto.labels.count).to eq 2
      end

      it 'returns latin script results by default' do
        get '/api/v1/labels/search', params: { query: @car_latn, language: @serbo_croat.iso639_3 }
  
        # expect(response.status).to eq 200
        expect(response.body).to include @car_latn
        expect(response.body).to_not include @car_cyrl
      end

      it 'returns cyrillic script results when requested' do
        get '/api/v1/labels/search', params: { query: @car_cyrl, language: @serbo_croat.iso639_3, script: 'cyrl' }
  
        # expect(response.status).to eq 200
        expect(response.body).to include @car_cyrl
        expect(response.body).to_not include @car_latn
      end
    end
    
    
    it 'returns the correct Picto with valid URLs' do
      source_picto = FactoryBot.create(:picto, :with_published_symbolset)
      source_picto.labels.first.update(text: 'fresh fruit now')

      get '/api/v1/labels/search', params: { query: 'fruit now' }

      expect(response).to have_http_status :success
      labels = JSON.parse(response.body)
      response_picto = labels.first['picto']
      pp response_picto
      expect(response_picto['id']).to eq source_picto.id
      expect(response_picto['image_url']).to eq source_picto.images.first.imagefile.url
      
      get response_picto['image_url']
      expect(response).to have_http_status :success
    end

    it 'returns results from a specific symbolset' do
      # Create two Pictos, in separate symbolsets.
      picto1 = FactoryBot.create(:picto, :with_published_symbolset)
      picto2 = FactoryBot.create(:picto, :with_published_symbolset)
      expect(picto1.symbolset).to_not eq picto2.symbolset
      
      # Set identical labels on both pictos
      picto1.labels.first.update!(text: 'good show')
      picto2.labels.first.update!(text: 'good hide')
      
      # Request suggestions for 'good' within symbolset1
      get '/api/v1/labels/search', params: { query: 'good', symbolset: picto1.symbolset.slug }
      
      expect(response.status).to eq(200)
      
      # Suggestions should contain the first picto, from the specified symbolset, and not the second picto
      expect(response.body).to include picto1.labels.first.text
      expect(response.body).to_not include picto2.labels.first.text
    end

    it 'returns HTTP 400 when filtering on an un-published Symbolset' do
      picto = FactoryBot.create(:picto)
      expect(picto.symbolset.status).to eq 'draft'
      
      get '/api/v1/labels/search', params: { query: 'example', symbolset: picto.symbolset.slug }
      
      expect(response.status).to eq(400)
      
      expect(response.body).to_not include picto.labels.first.text
      expect(response.body).to_not include picto.symbolset.id.to_s
    end
    
    it 'does not expose pictos from un-published Symbolsets' do
      # Create two Pictos, in separate symbolsets.
      draft_picto = FactoryBot.create(:picto)
      published_picto = FactoryBot.create(:picto, :with_published_symbolset)
      expect(draft_picto.symbolset).to_not eq published_picto.symbolset
      
      # picto1's symbolset should be draft.
      expect(draft_picto.symbolset.status).to eq 'draft'

      # Set picto2's symbolset to be published.
      published_picto.symbolset.update!(status: :published)
      expect(published_picto.symbolset.status).to eq 'published'
  
      # Set identical labels on both pictos
      draft_picto.labels.first.update(text: 'good draft')
      published_picto.labels.first.update(text: 'good published')
      
      get '/api/v1/labels/search', params: { query: 'good' }
  
      expect(response.status).to eq(200)

      expect(JSON.parse(response.body).count).to eq 1
      expect(response.body).to_not include draft_picto.labels.first.text
    end

    describe 'Archived symbols' do
      it 'does not return archived symbols' do
        picto = FactoryBot.create(:picto, :with_published_symbolset, archived: true)
        picto.labels.first.update(text: 'archived')
        get '/api/v1/labels/search', params: { query: 'archived' }

        expect(response.status).to eq 200
        expect(JSON.parse(response.body).count).to eq 0
        expect(response.body).to_not include 'archived'
      end
    end
    
    it 'applies a limit to the number of results' do
      # Create 5 symbols in a published symbol set, all with the same labels
      symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 5)
      Label.joins(:picto).where(pictos: {symbolset: symbolset}).update_all(text: 'test')
      
      # Verify that we have 5 identical labels
      expect(symbolset.pictos.joins(:labels).where(labels: {text: 'test'}).count).to eq 5
      
      # Search for the label
      get '/api/v1/labels/search', params: { query: 'test', limit: 1 }

      expect(response.status).to eq 200
      
      # We should have just one, as per the limit.
      expect(JSON.parse(response.body).count).to eq 1
    end

    it 'returns results from a specific language, specified by ISO639_3 code' do
      picto1 = FactoryBot.create(:picto, :with_published_symbolset)
      picto2 = FactoryBot.create(:picto, :with_published_symbolset)
  
      picto1.labels.first.update(text: 'good/bien', language: FactoryBot.create(:language))
      picto2.labels.first.update(text: 'good/gut', language: FactoryBot.create(:language))
  
      get '/api/v1/labels/search', params: { query: 'good', language: picto1.labels.first.language.iso639_3 }
      
      expect(response.status).to eq 200
      expect(JSON.parse(response.body).count).to eq 1
      expect(response.body).to include picto1.labels.first.text
      expect(response.body).to_not include picto2.labels.first.text
    end

    it 'searches using ISO639_3 codes by default' do
      picto1 = FactoryBot.create(:picto, :with_published_symbolset)
      label  = picto1.labels.first
      label.update!(text: 'good', language: FactoryBot.create(:language))
      
      get '/api/v1/labels/search', params: { query: 'good', language: label.language.iso639_3 }

      expect(response.status).to eq 200
      expect(JSON.parse(response.body).count).to eq 1
      expect(response.body).to include label.text
    end

    it 'searches using other ISO639 codes when specified' do
      picto1 = FactoryBot.create(:picto, :with_published_symbolset)
      label  = picto1.labels.first
      label.update!(text: 'good', language: FactoryBot.create(:language))
      get '/api/v1/labels/search', params: { query: 'good', language: label.language.iso639_1, language_iso_format: '639-1' }

      expect(response.status).to eq 200
      expect(JSON.parse(response.body).count).to eq 1
      expect(response.body).to include label.text
    end
    
    it "returns labels ordered by whole word match first" do
  
      # These Labels are in the wrong order, deliberately, given that we will search for 'dog'.
      words = [
          'dogmatic',
          'dog',
          'boondoggle',
          'seadog',
          'top_dog',
          'dog_days',
          'my_dog_smells'
      ]
      
      symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: words.count)
      
      # Update each Label in the Symbolset with the words.
      words.each_with_index do |word, index|
        symbolset.pictos[index].labels.first.update(text: word)
      end

      get '/api/v1/labels/search', params: { query: 'dog' }

      expect(response.status).to eq 200
      json = JSON.parse(response.body)

      # Check the labels have been re-ordered correctly.
      expect(json[0]['text']).to eq 'dog'           # whole word
      expect(json[1]['text']).to eq 'dog_days'      # phrase start whole word
      expect(json[2]['text']).to eq 'top_dog'       # phrase end whole word
      expect(json[3]['text']).to eq 'my_dog_smells' # within phrase whole word
      expect(json[4]['text']).to eq 'dogmatic'      # phrase start part of a word
      expect(json[5]['text']).to eq 'seadog'        # phrase end part of a word
      expect(json[6]['text']).to eq 'boondoggle'    # within phrase, part of a word
    end
    
    it 'returns 400 for requests with no query param' do
      get '/api/v1/labels/search'
      expect(response.status).to eq(400)
    end
  end

  context 'GET /api/v1/labels/{id}' do
    
    context 'for a missing Label' do
      it 'returns 404' do
        get '/api/v1/labels/94'
        expect(response.status).to eq(404)
      end
    end

    context 'for an existing published Label' do
      it 'returns the label' do
        picto = FactoryBot.create(:picto, :with_published_symbolset)
        expect(picto.symbolset.status).to eq 'published'
    
        get "/api/v1/labels/#{picto.labels.first.id}"
        expect(response.status).to eq 200
        expect(response.body).to include picto.id.to_s
        expect(response.body).to include picto.labels.first.id.to_s
      end
    end

    context 'for an existing unpublished Label' do
      it 'returns 404' do
        picto = FactoryBot.create(:picto)
        expect(picto.symbolset.status).to eq 'draft'
    
        get "/api/v1/labels/#{picto.labels.first.id}"
        expect(response.status).to eq 404
        expect(JSON.parse(response.body)['id']).to be nil
      end
    end
  end
end