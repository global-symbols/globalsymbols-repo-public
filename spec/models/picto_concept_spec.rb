require 'rails_helper'

RSpec.describe PictoConcept, type: :model do
  context "with minimum parameters" do
    it "creates a PictoConcept" do
      expect(FactoryBot.create(:picto_concept)).to be_a PictoConcept
    end
    
    it "allows traversal to associated Pictos" do
      picto = FactoryBot.create(:picto)
      pc = FactoryBot.create(:picto_concept, picto:picto)
      expect(pc.picto).to be picto
    end

    it "allows traversal to associated Concepts" do
      concept = FactoryBot.create(:concept)
      pc = FactoryBot.create(:picto_concept, concept:concept)
      expect(pc.concept).to be concept
    end
  end
  
  context "with missing Concept or Picto" do
    it "fails validation" do
      expect{FactoryBot.create(:picto_concept, concept:nil)}.to raise_error ActiveRecord::RecordInvalid
      expect{FactoryBot.create(:picto_concept, picto:nil)}.to raise_error ActiveRecord::RecordInvalid
    end
  end
end
