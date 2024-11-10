require 'rails_helper'

RSpec.describe Users::RegistrationsController, type: :controller do
  before :each do
    @request.env["devise.mapping"] = Devise.mappings[:user]
  end
  
  describe 'POST #create' do
    it 'registers a user' do
      # We have to set the attributes by hand.
      # Using FactoryBot.build(:user).attributes will fail because these are attributes for the model (e.g. including encrypted_password), and not attributes for the form.
      attributes = FactoryBot.attributes_for(:user)
      attributes[:language_id] = attributes[:language].id
      expect {
        post :create, params: {user: attributes}
      }.to change(User, :count).by(1)
    end
  end
end