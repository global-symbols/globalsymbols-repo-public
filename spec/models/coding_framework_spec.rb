require 'rails_helper'

RSpec.describe CodingFramework, type: :model do
  context "with minimum parameters" do
    it "creates a CCF" do
      ccf = FactoryBot.create(:coding_framework)
      expect(ccf).to be_a(CodingFramework)
    end
  end
  
  context "with type set to linked_data" do
    it "fails validation without a uri_base" do
      expect{FactoryBot.create(:coding_framework, {structure: :linked_data, api_uri_base: nil})}.to raise_error ActiveRecord::RecordInvalid
    end
    
    it "passes validation without a uri_base" do
      expect{FactoryBot.create(:coding_framework, {structure: :linked_data, api_uri_base: '/base'})}.not_to raise_error
    end
  end
  
  context "with name or type missing" do
    it "fails validation" do
      expect{FactoryBot.create(:coding_framework, {structure: nil, name: nil})}.to raise_error ActiveRecord::RecordInvalid
    end
  end
  
  context "with associated Concepts" do
    it "allows traversal to the Concepts" do
      ccf = FactoryBot.create(:coding_framework, :with_concepts)
      expect(ccf).to be_a(CodingFramework)
      expect(ccf.concepts.first).to be_a(Concept)
      expect(ccf.concepts.count).to be > 1
    end
  end
end
