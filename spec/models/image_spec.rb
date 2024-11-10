require 'rails_helper'

RSpec.describe Image, type: :model do
  context "with minimum parameters" do
    it "creates an Image with a parent Picto" do
      image = FactoryBot.create(:image)
      expect(image).to be_a(Image)
      expect(image.picto).to be_a(Picto)
    end
  end
  
  context "with invalid parameters" do
    it "prevents creation of an image" do
      expect{FactoryBot.create(:image, picto: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
  end
end