require 'rails_helper'

RSpec.describe PictoConceptsController, type: :controller do
  
  before :each do
    @pc = FactoryBot.create(:picto_concept)
  end
  
  describe "GET #index" do
    context "for Collaborators on the Symbolset" do
      it "successfully renders the view" do
        sign_in @pc.picto.symbolset.users.first
        get :index, params: {symbolset_id: @pc.picto.symbolset, symbol_id: @pc.picto}
        expect(response).to have_http_status :success
        expect(response).to render_template('index')
      end
    end
    context "for unauthorised users" do
      it "redirects guests to sign in" do
        get :index, params: {symbolset_id: @pc.picto.symbolset, symbol_id: @pc.picto}
        expect(response).to redirect_to(new_user_session_path)
      end
      
      it "denies the action to Users who are not Collaborators on the Symbolset" do
        sign_in FactoryBot.create(:user)
        get :index, params: {symbolset_id: @pc.picto.symbolset, symbol_id: @pc.picto}
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe "POST #create" do
    before :each do
      @symbolset = FactoryBot.create(:symbolset, :with_pictos)
    end
    context "for Collaborators on the Symbolset" do
      context "with valid parameters" do
        it "successfully creates the PictoConcept" do
          sign_in @symbolset.users.first
          expect{post :create, params: {symbolset_id: @symbolset, symbol_id: @symbolset.pictos.first, concept: 'cat'}}.to change(PictoConcept, :count).by 1
          post :create, params: {symbolset_id: @symbolset, symbol_id: @symbolset.pictos.first, concept: 'mouse'}
          expect(response).to redirect_to symbolset_symbol_concepts_path
        end
      end
      context "with invalid parameters" do
        it "redirects back to #index when creating a duplicated PictoConcept" do
          sign_in @symbolset.users.first
          post :create, params: {symbolset_id: @symbolset, symbol_id: @symbolset.pictos.first, concept: 'cat'}
          post :create, params: {symbolset_id: @symbolset, symbol_id: @symbolset.pictos.first, concept: 'cat'}
          expect(response).to redirect_to symbolset_symbol_concepts_path
        end
      end
    end
    context "for unauthorised users" do
      it "redirects guests to sign in" do
        post :create, params: {symbolset_id: @symbolset, symbol_id: @symbolset.pictos.first, concept: 'cat'}
        expect(response).to redirect_to(new_user_session_path)
      end
    
      it "denies the action to Users who are not Collaborators on the Symbolset" do
        sign_in FactoryBot.create(:user)
        post :create, params: {symbolset_id: @symbolset, symbol_id: @symbolset.pictos.first, concept: 'cat'}
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe "DELETE #destroy" do
    before :each do
      @pc = FactoryBot.create(:picto_concept)
    end
    context "for Collaborators on the Symbolset" do
      context "with valid parameters" do
        it "successfully deletes the PictoConcept" do
          sign_in @pc.picto.symbolset.users.first
          expect{delete :destroy, params: {symbolset_id: @pc.picto.symbolset, symbol_id: @pc.picto, id: @pc}}.to change(PictoConcept, :count).by -1
        end
        it "redirects to the symbol concepts path" do
          sign_in @pc.picto.symbolset.users.first
          delete :destroy, params: {symbolset_id: @pc.picto.symbolset, symbol_id: @pc.picto, id: @pc}
          expect(response).to redirect_to symbolset_symbol_concepts_path
        end
      end
      context "with invalid parameters" do
        context "when the User tries to delete Concepts from another Symbolset" do
          it "returns unauthorised" do
            @picto = FactoryBot.create(:picto)
            sign_in @pc.picto.symbolset.users.first
            
            delete :destroy, params: {symbolset_id: @pc.picto.symbolset, symbol_id: @picto, id: @pc}
            expect(response).to have_http_status :unauthorized
          end
        end
      end
    end
    context "for unauthorised users" do
      it "redirects guests to sign in" do
        delete :destroy, params: {symbolset_id: @pc.picto.symbolset, symbol_id: @pc.picto, id: @pc}
        expect(response).to redirect_to(new_user_session_path)
      end
    
      it "denies the action to Users who are not Collaborators on the Symbolset" do
        sign_in FactoryBot.create(:user)
        delete :destroy, params: {symbolset_id: @pc.picto.symbolset, symbol_id: @pc.picto, id: @pc}
        expect(response).to have_http_status :unauthorized
      end
    end
  end

end
