require 'rails_helper'

RSpec.describe User, type: :model do
  context "with minimum parameters" do
    it "creates a user" do
      expect{FactoryBot.create(:user)}.to_not raise_error
    end

    it "creates a low-privilege user" do
      user = FactoryBot.create(:user)
      expect(user.role).to eq('user')
    end
  end
  
  context "with invalid parameters" do
    it "prevents creation of the User without a Language" do
      expect{FactoryBot.create(:user, language: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
    it "prevents creation of the User without a first name" do
      expect{FactoryBot.create(:user, prename: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
    it "prevents creation of the User without a surname" do
      expect{FactoryBot.create(:user, surname: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
  end
  
  context "with admin role" do
    it "creates an admin user" do
      user = FactoryBot.create(:user, :admin)
      expect(user.role).to eq('admin')
    end
  end

  context "with a SymbolsetUser" do
    it "returns the symbolset" do
      symbolset = FactoryBot.create(:symbolset)
      user = FactoryBot.create(:user)
      user.symbolsets << symbolset

      expect(user.symbolsets).to contain_exactly(symbolset)
    end
  end
  
  context "with Comments" do
    it "allows traversal to the Comments" do
      user = FactoryBot.create(:user, comments_count: 3)
    
      expect(user.comments.count).to eq 3
      expect(user.comments.first).to be_a Comment
    end
  end
end