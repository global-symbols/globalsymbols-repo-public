require "rails_helper"

RSpec.describe Symbolset, type: :model do
  
  context "with minimum parameters" do
    it "creates a draft symbolset" do
      symbolset = FactoryBot.create(:symbolset)
    
      expect(symbolset.status).to eq('draft')
    end

    it "returns the user" do
      symbolset = FactoryBot.create(:symbolset)
  
      expect(symbolset.users.count).to be > 0
    end
    
    it "strips white space from attributes" do
      symbolset = FactoryBot.create(:symbolset, name: ' test ')
      expect(symbolset.name).to eq 'test'
    end
  end

  context "with invalid parameters" do
    it "fails validation with missing parameters" do
      expect{FactoryBot.create(:symbolset, name: nil)}.to raise_error ActiveRecord::RecordInvalid
      expect{FactoryBot.create(:symbolset, publisher: nil)}.to raise_error ActiveRecord::RecordInvalid
      expect{FactoryBot.create(:symbolset, status: nil)}.to raise_error ActiveRecord::RecordInvalid
    end

    it "fails validation when created, if status is not draft" do
      expect{FactoryBot.create(:symbolset, status: :published)}.to raise_error ActiveRecord::RecordInvalid
    end

    it "passes validation when updated, with any status" do
      symbolset = FactoryBot.create :symbolset
      expect{symbolset.update(status: :published)}.not_to raise_error
      expect{symbolset.update(status: :draft)}.not_to raise_error
    end

    it "prevents another Symbolset being made with the same name" do
      FactoryBot.create(:symbolset, name: 'MegaSymbols')
      expect{FactoryBot.create(:symbolset, name: 'MegaSymbols')}.to raise_error ActiveRecord::RecordInvalid
    end
    
    it "prevents another Symbolset being made with the same slug" do
      FactoryBot.create(:symbolset, slug: 'mega-symbols')
      expect{FactoryBot.create(:symbolset, slug: 'mega-symbols')}.to raise_error ActiveRecord::RecordInvalid
    end
  end
  
  context "with minimum parameters and a Picto" do
    it "allows traversal to the Picto" do
      symbolset = FactoryBot.create(:symbolset)
      picto = FactoryBot.create(:picto, symbolset: symbolset)

      expect(symbolset).to be_a(Symbolset)
      expect(symbolset.pictos).to contain_exactly(picto)
    end
  end
  
  context "with a Survey" do
    it "allows traversal to the Survey" do
      symbolset = FactoryBot.create(:symbolset)
      symbolset.surveys.create(name: 'test')
      expect(symbolset.surveys.first).to be_a Survey
    end
  end
  
  context "when destroying the Symbolset" do
    it "destroys successfully, even with associated records" do
      symbolset = FactoryBot.create(:symbolset)
      symbolset.surveys.create(name: 'test')
      expect{
        symbolset.destroy
      }.to change(Symbolset, :count).by -1
    end
  end
end