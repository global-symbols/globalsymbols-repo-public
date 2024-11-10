require 'rails_helper'

RSpec.describe Category, type: :model do
  context "with minimum parameters" do
    it "creates a Category" do
      category = FactoryBot.create(:category)
      expect(category).to be_a(Category)
    end
    it "prevents creation of duplicate Categories" do
      category = FactoryBot.create(:category)
      expect{FactoryBot.create(:category, name: category.name)}.to raise_exception ActiveRecord::RecordInvalid
      expect{FactoryBot.create(:category, concept_id: category.concept_id)}.to raise_exception ActiveRecord::RecordInvalid
    end
    it "allows traversal to Pictos" do
      category = FactoryBot.create(:category, :with_pictos)
      expect(category.pictos.count).to be > 0
    end
  end
  context "with invalid parameters" do
    it "raises a validation exception" do
      expect{FactoryBot.create(:category, name: nil)}.to raise_exception ActiveRecord::RecordInvalid
    end
  end
end
