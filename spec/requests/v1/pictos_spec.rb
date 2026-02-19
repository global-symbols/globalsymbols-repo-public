require 'rails_helper'

RSpec.describe GlobalSymbols::V1::Pictos, type: :request do
  context 'GET /api/v1/pictos' do
    
    it 'returns paginated pictos for a published symbolset' do
      symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 3)
      
      get '/api/v1/pictos', params: { symbolset: symbolset.slug }
      
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      
      expect(json).to have_key('items')
      expect(json).to have_key('total')
      expect(json['total']).to eq(3)
      expect(json['items'].count).to eq(3)
      
      # Verify each picto has required fields
      json['items'].each do |picto|
        expect(picto).to have_key('id')
        expect(picto).to have_key('part_of_speech')
        expect(picto).to have_key('image_url')
        expect(picto).to have_key('native_format')
        expect(picto).to have_key('labels')
        expect(picto['labels']).to be_an(Array)
      end
    end
    
    it 'includes labels with language codes for each picto' do
      symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 1)
      picto = symbolset.pictos.first
      
      # Create additional labels in different languages
      english = Language.find_by(iso639_3: 'eng') || Language.find_by(iso639_1: 'en')
      spanish = Language.find_by(iso639_3: 'spa') || Language.find_by(iso639_1: 'es')
      
      if english
        FactoryBot.create(:label, picto: picto, language: english, text: 'computer')
      end
      if spanish
        FactoryBot.create(:label, picto: picto, language: spanish, text: 'computadora')
      end
      
      get '/api/v1/pictos', params: { symbolset: symbolset.slug }
      
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      
      labels = json['items'].first['labels']
      expect(labels).to be_an(Array)
      expect(labels.length).to be >= 1
      
      # Verify label structure
      labels.each do |label|
        expect(label).to have_key('language')
        expect(label).to have_key('text')
        expect(label['language']).to be_a(String)
        expect(label['text']).to be_a(String)
      end
    end
    
    it 'only returns authoritative labels' do
      symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 1)
      picto = symbolset.pictos.first
      
      # Create an authoritative label
      authoritative_source = FactoryBot.create(:source, authoritative: true)
      authoritative_label = FactoryBot.create(:label, picto: picto, source: authoritative_source, text: 'authoritative label')
      
      # Create a non-authoritative label (suggestion)
      suggestion_source = FactoryBot.create(:source, authoritative: false, slug: 'translation-suggestion')
      suggestion_label = FactoryBot.create(:label, picto: picto, source: suggestion_source, text: 'suggestion label')
      
      get '/api/v1/pictos', params: { symbolset: symbolset.slug }
      
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      
      labels = json['items'].first['labels']
      label_texts = labels.map { |l| l['text'] }
      
      expect(label_texts).to include('authoritative label')
      expect(label_texts).not_to include('suggestion label')
    end
    
    it 'enforces symbolset scoping - only returns pictos from specified symbolset' do
      symbolset1 = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 2)
      symbolset2 = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 3)
      
      get '/api/v1/pictos', params: { symbolset: symbolset1.slug }
      
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      
      expect(json['total']).to eq(2)
      expect(json['items'].count).to eq(2)
      
      # Verify all returned pictos belong to symbolset1
      returned_ids = json['items'].map { |p| p['id'] }
      symbolset1_ids = symbolset1.pictos.pluck(:id)
      symbolset2_ids = symbolset2.pictos.pluck(:id)
      
      expect(returned_ids).to match_array(symbolset1_ids)
      expect(returned_ids & symbolset2_ids).to be_empty
    end
    
    it 'rejects missing symbolset parameter' do
      get '/api/v1/pictos'
      
      expect(response.status).to eq(400)
    end
    
    it 'rejects draft symbolset slug' do
      symbolset = FactoryBot.create(:symbolset, status: :draft, :with_pictos)
      
      get '/api/v1/pictos', params: { symbolset: symbolset.slug }
      
      expect(response.status).to eq(400)
    end
    
    it 'filters out archived pictos' do
      symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 2)
      symbolset.pictos.first.update!(archived: true)
      
      get '/api/v1/pictos', params: { symbolset: symbolset.slug }
      
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      
      expect(json['total']).to eq(1)
      expect(json['items'].count).to eq(1)
      expect(json['items'].first['id']).to eq(symbolset.pictos.where(archived: false).first.id)
    end
    
    it 'filters out non-public pictos (visibility: collaborators)' do
      symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 2)
      symbolset.pictos.first.update!(visibility: :collaborators)
      
      get '/api/v1/pictos', params: { symbolset: symbolset.slug }
      
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      
      expect(json['total']).to eq(1)
      expect(json['items'].count).to eq(1)
      expect(json['items'].first['id']).to eq(symbolset.pictos.where(visibility: :everybody).first.id)
    end
    
    context 'pagination' do
      before :each do
        @symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 5)
      end
      
      it 'returns first page with default per_page' do
        get '/api/v1/pictos', params: { symbolset: @symbolset.slug, page: 1 }
        
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        
        expect(json['total']).to eq(5)
        expect(json['items'].count).to eq(5) # default per_page is 100, so all fit
      end
      
      it 'respects per_page parameter' do
        get '/api/v1/pictos', params: { symbolset: @symbolset.slug, page: 1, per_page: 2 }
        
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        
        expect(json['total']).to eq(5)
        expect(json['items'].count).to eq(2)
      end
      
      it 'returns correct page when page parameter is specified' do
        get '/api/v1/pictos', params: { symbolset: @symbolset.slug, page: 2, per_page: 2 }
        
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        
        expect(json['total']).to eq(5)
        expect(json['items'].count).to eq(2)
        
        # Verify it's the second page (items 3 and 4)
        first_page_ids = @symbolset.pictos.order(:id).limit(2).pluck(:id)
        second_page_ids = @symbolset.pictos.order(:id).offset(2).limit(2).pluck(:id)
        returned_ids = json['items'].map { |p| p['id'] }
        
        expect(returned_ids).to match_array(second_page_ids)
        expect(returned_ids & first_page_ids).to be_empty
      end
      
      it 'returns empty items array for page beyond available items' do
        get '/api/v1/pictos', params: { symbolset: @symbolset.slug, page: 10, per_page: 2 }
        
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        
        expect(json['total']).to eq(5)
        expect(json['items']).to eq([])
      end
      
      it 'caps per_page at 100' do
        get '/api/v1/pictos', params: { symbolset: @symbolset.slug, page: 1, per_page: 200 }
        
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        
        expect(json['items'].count).to be <= 100
      end
      
      it 'handles page 0 or negative as page 1' do
        get '/api/v1/pictos', params: { symbolset: @symbolset.slug, page: 0, per_page: 2 }
        
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        
        expect(json['items'].count).to eq(2)
      end
    end
    
    it 'includes text_diacritised when present' do
      symbolset = FactoryBot.create(:symbolset, :published, :with_pictos, pictos_count: 1)
      picto = symbolset.pictos.first
      
      arabic = Language.find_by(iso639_3: 'ara')
      if arabic
        label = FactoryBot.create(:label, picto: picto, language: arabic, text: 'حاسوب', text_diacritised: 'حاسوب')
        
        get '/api/v1/pictos', params: { symbolset: symbolset.slug }
        
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        
        arabic_label = json['items'].first['labels'].find { |l| l['language'] == 'ara' }
        expect(arabic_label).to have_key('text_diacritised')
        expect(arabic_label['text_diacritised']).to eq('حاسوب')
      end
    end
  end
end
