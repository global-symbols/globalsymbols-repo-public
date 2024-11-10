require 'rails_helper'

RSpec.describe Licence, type: :model do
  context "with valid parameters" do
    it "creates a Licence" do
      licence = FactoryBot.create(:licence)
      expect(licence).to be_a(Licence)
    end
    
    it "allows creation of multiple Licences without URLs" do
      FactoryBot.create(:licence)
      expect{FactoryBot.create(:licence)}.to_not raise_error
    end
  end
  
  context "with invalid parameters" do
    it "prevents creation of a Licence with no name" do
      expect{FactoryBot.create(:licence, name: nil)}.to raise_error ActiveRecord::RecordInvalid
    end

    it "prevents creation of a duplicate Licence" do
      licence = FactoryBot.create(:licence, :creative_commons)
      expect{FactoryBot.create(:licence, name: licence.name)}.to raise_error ActiveRecord::RecordInvalid
      expect{FactoryBot.create(:licence, url: licence.url)}.to raise_error ActiveRecord::RecordInvalid
    end
  end
end
