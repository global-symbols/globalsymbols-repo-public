require 'rails_helper'

RSpec.describe PagesController, type: :controller do

  describe "GET #home" do
    it "returns http success" do
      get :home
      expect(response).to have_http_status :success
    end

    it "displays only published, featured symbol sets when signed out" do
      published_symbolset = FactoryBot.create :symbolset, :published, featured_level: 1
      draft_symbolset = FactoryBot.create :symbolset, status: :draft, featured_level: 1
      non_featured_symbolset = FactoryBot.create :symbolset, status: :draft, featured_level: nil
      get :home
      expect(assigns(:symbolsets).count).to eq 1
      expect(assigns(:symbolsets)).to include published_symbolset
      expect(assigns(:symbolsets)).to_not include draft_symbolset
      expect(assigns(:symbolsets)).to_not include non_featured_symbolset
    end
    
    it "displays symbol sets in order of featured_level then name" do
      non_featured_symbolset = FactoryBot.create :symbolset, :published, featured_level: nil
      bottom_symbolset = FactoryBot.create :symbolset, :published, featured_level: 2
      middle_symbolset = FactoryBot.create :symbolset, :published, featured_level: 1, name: 'Z Symbolset'
      top_symbolset = FactoryBot.create :symbolset, :published, featured_level: 1, name: 'A Symbolset'
      get :home
      expect(assigns(:symbolsets)).to eq [top_symbolset, middle_symbolset, bottom_symbolset]
    end
  end
  
  describe "GET #search" do
    it "returns results for the specified query" do
      picto1 = FactoryBot.create(:picto, :with_published_symbolset)
      picto2 = FactoryBot.create(:picto, :with_published_symbolset)
      
      get :search, params: { query: picto1.labels.first.text }

      expect(response).to be_successful
      expect(assigns(:labels)).to include picto1.labels.first
      expect(assigns(:labels)).to_not include picto2.labels.first
    end

    it "does not return results for un-published symbolsets" do
      picto = FactoryBot.create(:picto)
  
      get :search, params: { query: picto.labels.first.text }
  
      expect(response).to be_successful
      expect(assigns(:labels)).to_not include picto.labels.first
    end

    describe 'Archived symbols' do
      it 'does not return archived symbols' do
        picto = FactoryBot.create(:picto, :with_published_symbolset, archived: true)
        get :search, params: { query: picto.labels.first.text }
        expect(response).to be_successful
        expect(assigns(:labels)).to_not include picto.labels.first
      end
    end

    it "returns results from a specified symbol set" do
      picto1 = FactoryBot.create(:picto, :with_published_symbolset)
      picto2 = FactoryBot.create(:picto, :with_published_symbolset)
      
      picto1.labels.first.update!(text: 'dog')
      picto2.labels.first.update!(text: 'dog')
      
      get :search, params: { query: 'dog', symbolset: picto1.symbolset.slug }
  
      expect(response).to be_successful
      expect(assigns(:labels)).to include picto1.labels.first
      expect(assigns(:labels)).to_not include picto2.labels.first
    end

    it "returns results from a specified language" do
      english_picto = FactoryBot.create(:picto, :with_published_symbolset)
      english_picto.labels.first.update!(language: Language.find_by(iso639_1: :en), text: 'dog')
      
      french_picto = FactoryBot.create(:picto, :with_published_symbolset)
      french_picto.labels.first.update!(language: Language.find_by(iso639_1: :fr), text: 'dog')
  
      get :search, params: { query: 'dog', language: Language.find_by(iso639_1: :en).iso639_3 }
  
      expect(response).to be_successful
      expect(assigns(:labels)).to include english_picto.labels.first
      expect(assigns(:labels)).to_not include french_picto.labels.first
    end

    it "returns results ordered correctly" do
      # Create the Labels in the wrong ordering
      dogmatic      = FactoryBot.create(:picto, :with_published_symbolset).labels.first
      dog           = FactoryBot.create(:picto, :with_published_symbolset).labels.first
      boondoggle    = FactoryBot.create(:picto, :with_published_symbolset).labels.first
      seadog        = FactoryBot.create(:picto, :with_published_symbolset).labels.first
      top_dog       = FactoryBot.create(:picto, :with_published_symbolset).labels.first
      dog_days      = FactoryBot.create(:picto, :with_published_symbolset).labels.first
      my_dog_smells = FactoryBot.create(:picto, :with_published_symbolset).labels.first

      # Set the label text
      dogmatic      .update!(text: 'dogmatic')
      dog           .update!(text: 'dog')
      boondoggle    .update!(text: 'boondoggle')
      seadog        .update!(text: 'seadog')
      top_dog       .update!(text: 'top dog')
      dog_days      .update!(text: 'dog days')
      my_dog_smells .update!(text: 'my dog smells')

      get :search, params: { query: 'dog' }
      
      # Check the labels have been re-ordered correctly.
      expect(assigns(:labels)[0]).to eq dog           # whole word
      expect(assigns(:labels)[1]).to eq dog_days      # phrase start whole word
      expect(assigns(:labels)[2]).to eq top_dog       # phrase end whole word
      expect(assigns(:labels)[3]).to eq my_dog_smells # within phrase whole word
      expect(assigns(:labels)[4]).to eq dogmatic      # phrase start part of a word
      expect(assigns(:labels)[5]).to eq seadog        # phrase end part of a word
      expect(assigns(:labels)[6]).to eq boondoggle    # within phrase, part of a word
    end
    
    context "for logged out users" do
      it "does not display private symbols" do
        picto = FactoryBot.create(:picto, visibility: :collaborators)
    
        get :search, params: { query: picto.labels.first.text }
        expect(response).to be_successful
        expect(assigns(:labels)).to_not include picto.labels.first
      end
    end
    
    context "for users authorised on a Symbol Set" do
      it "displays private symbols in the symbol set" do
        picto = FactoryBot.create(:picto, visibility: :collaborators)
        sign_in picto.symbolset.users.first
  
        get :search, params: { query: picto.labels.first.text }
        expect(response).to be_successful
        expect(assigns(:labels)).to include picto.labels.first
      end
    end
    
    # TODO: trim text in search and API
    it 'trims text'
  end
end
