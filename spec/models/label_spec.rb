require 'rails_helper'

RSpec.describe Label, type: :model do
  context "with minimum parameters" do
    it "creates a Label with a parent Picto" do
      picto = FactoryBot.create(:picto)
      expect(picto.labels.first).to be_a(Label)
    end
  end
  
  context "with invalid parameters" do
    it "prevents creation of a Label" do
      expect{FactoryBot.create(:label, picto: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
  end
end
