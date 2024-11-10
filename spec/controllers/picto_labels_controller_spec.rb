require 'rails_helper'

RSpec.describe PictoLabelsController, type: :controller do
  before :each do
    @unauthorised_user = FactoryBot.create(:user)
  end

  describe "GET #index" do
    before :each do
      @symbolset = FactoryBot.create(:symbolset, :with_pictos)
    end

    context "for users authorised on the symbolset" do
      it "renders the edit form" do
        sign_in @symbolset.users.first
        get :index, params: {symbol_id: @symbolset.pictos.first.id, symbolset_id: @symbolset }
        expect(response).to render_template('index')
      end
    end

    context "for users not authorised on the symbolset" do
      it "redirects unauthenticated visitors to sign in" do
        get :index, params: {symbol_id: @symbolset.pictos.first.id, symbolset_id: @symbolset }
        expect(response).to redirect_to(new_user_session_path)
      end

      it "denies the action to non-members of the symbolset" do
        sign_in @unauthorised_user
        get :index, params: {symbol_id: @symbolset.pictos.first.id, symbolset_id: @symbolset }
        expect(response).to have_http_status :unauthorized
      end
    end
  end
end
