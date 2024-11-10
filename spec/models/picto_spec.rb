require 'rails_helper'

RSpec.describe Picto, type: :model do
  context "with minimum parameters" do
    it "creates a Picto within a Symbolset" do
      picto = FactoryBot.create(:picto)
      expect(picto).to be_a(Picto)
      expect(picto.symbolset).to be_a(Symbolset)
    end

    it "allows traversal to child Images" do
      picto = FactoryBot.create(:picto, images_count: 2)
      expect(picto).to be_a(Picto)
      expect(picto.images.first).to be_an(Image)
      expect(picto.images.count).to be 2
    end

    it "is not archived" do
      picto = FactoryBot.create(:picto)
      expect(picto.archived).to be false
    end
  end
  
  context "without a symbolset" do
    it "cannot be created" do
      expect{FactoryBot.create(:picto, symbolset: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
  end
  
  context "with concepts available" do
    it "allows assignment and traversal to the concepts" do
      picto = FactoryBot.create(:picto, :with_concepts)
      expect(picto.concepts.first).to be_a Concept
      expect(picto.concepts.count).to be > 1
    end

    it "prevents the same Concept being added to a Picto twice" do
      picto = FactoryBot.create(:picto, :with_concepts)
      expect{picto.concepts << picto.concepts.first}.to raise_error ActiveRecord::RecordInvalid
    end
  end
  
  context "with an un-published Symbolset" do
    it "filters out Pictos when using the :published scope" do
      picto = FactoryBot.create(:picto)
      picto.symbolset.update(status: :draft)
      expect(Picto.published).to_not include picto
    end
  end

  context "with Surveys" do
    it "allows traversal to the Surveys" do
      picto = FactoryBot.create :picto, :with_survey
      expect(picto.surveys.count).to eq 1
      expect(picto.surveys.first).to be_a Survey
    end
  end

  context "with Comments" do
    it "allows traversal to the Comments" do
      picto = FactoryBot.create(:picto, comments_count: 3)
    
      expect(picto.comments.count).to eq 3
      expect(picto.comments.first).to be_a Comment
    end
  end
end
