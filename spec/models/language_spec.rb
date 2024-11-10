require 'rails_helper'

RSpec.describe Language, type: :model do
  context "with minimum parameters" do
    it "creates an Individual Language" do
      language = FactoryBot.create(:language)
      expect(language).to be_a(Language)
      expect(language.scope).to eq('I')
    end
  end
  
  context "with invalid parameters" do
    it "prevents creation of a duplicate Language" do
      language = FactoryBot.create(:language)
      expect{FactoryBot.create(:language, language.attributes)}.to raise_error ActiveRecord::RecordInvalid
    end
    
    it "prevents creation of a Language with missing parameters" do
      expect{FactoryBot.create(:language, name: nil)}.to raise_error ActiveRecord::RecordInvalid
      expect{FactoryBot.create(:language, iso639_3: nil)}.to raise_error ActiveRecord::RecordInvalid
      expect{FactoryBot.create(:language, scope: nil)}.to raise_error ActiveRecord::RecordInvalid
      expect{FactoryBot.create(:language, category: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
  end

  context "with related Macro and Individual Languages" do
    it "creates a Macro Language" do
      macrolanguage = FactoryBot.create(:macrolanguage)
      expect(macrolanguage).to be_a(Language)
      expect(macrolanguage.scope).to eq('M')
    end

    it "creates a Individual Languages within a Macrolanguage" do
      macrolanguage = FactoryBot.create(:macrolanguage, :with_individual_languages)
      expect(macrolanguage).to be_a(Language)
      expect(macrolanguage.scope).to eq('M')
      expect(macrolanguage.languages.first).to be_a(Language)
      expect(macrolanguage.languages.first.scope).to eq('I')
    end
    
    it 'allows traversal from a Macrolanguage to Individual Languages' do
      macrolanguage = FactoryBot.create(:macrolanguage, :with_individual_languages)
      expect(macrolanguage.languages.first).to be_a(Language)
      expect(macrolanguage.languages.first.scope).to eq('I')
    end

    it 'allows traversal from an Individual to its Macrolanguage' do
      macrolanguage = FactoryBot.create(:macrolanguage, :with_individual_languages)
      expect(macrolanguage.languages.first.macrolanguage).to be(macrolanguage)
    end
  end
end
