require 'rails_helper'

RSpec.describe SymbolsetUser, type: :model do
  context "with valid parameters" do
    it "validates and creates an editor symbolsetuser" do
      symbolsetuser = FactoryBot.create(:symbolset_user)
      expect(symbolsetuser.role).to eq('editor')
    end
    
    it "returns the correct records when traversing to User or Symbolset" do
      symbolset = FactoryBot.create(:symbolset)
      user = FactoryBot.create(:user)
      symbolsetuser = FactoryBot.create(:symbolset_user, user:user, symbolset:symbolset)
      expect(symbolsetuser.symbolset).to be(symbolset)
      expect(symbolsetuser.user).to be(user)
    end
  end

  context "with invalid parameters" do
    it "fails validation" do
      expect{FactoryBot.create(:symbolset_user, symbolset: nil)}.to raise_error ActiveRecord::RecordInvalid
      expect{FactoryBot.create(:symbolset_user, user: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
    
    it "prevents creation of duplicate SymbolsetUsers" do
      ssu = FactoryBot.create(:symbolset_user)
      expect{FactoryBot.create(:symbolset_user, symbolset: ssu.symbolset, user: ssu.user)}.to raise_error ActiveRecord::RecordInvalid
    end
  end
  
  context "with a User, Symbolset and admin role specified" do
    it "validates and creates an editor symbolsetuser" do
      symbolsetuser = FactoryBot.create(:symbolset_user, :admin)
      
      expect(symbolsetuser.role).to eq('admin')
    end
  end
end
