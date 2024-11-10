require 'rails_helper'

RSpec.describe CollaboratorsController, type: :controller do
  
  before :each do
    @symbolset = FactoryBot.create(:symbolset, users_count: 3)
  end
  
  describe "GET #index" do
    context "for Collaborators on the Symbolset" do
      it "successfully renders the view" do
        sign_in @symbolset.users.first
        get :index, params: {symbolset_id: @symbolset.slug}
        expect(response).to be_successful
        expect(response).to render_template('index')
      end
    end
    context "for unauthorised users" do
      it "redirects guests to sign in" do
        get :index, params: {symbolset_id: @symbolset.slug}
        expect(response).to redirect_to(new_user_session_path)
      end
      
      it "denies the action to Users who are not Collaborators on the Symbolset" do
        sign_in FactoryBot.create(:user)
        get :index, params: {symbolset_id: @symbolset.slug}
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe "POST #create" do
    context "for Collaborators on the Symbolset" do
      context "with valid parameters" do
        it "successfully creates the Collaborator" do
          sign_in @symbolset.users.first
          expect{
            post :create, params: {symbolset_id: @symbolset.slug, email: FactoryBot.create(:user).email}
          }.to change(SymbolsetUser, :count).by 1
          post :create, params: {symbolset_id: @symbolset.slug, email: FactoryBot.create(:user).email}
          expect(response).to redirect_to symbolset_collaborators_path @symbolset
        end
      end
      context "with invalid parameters" do
        it "redirects back to #index" do
          sign_in @symbolset.users.first
          expect{
            post :create, params: {symbolset_id: @symbolset.slug, email: @symbolset.users.first.email}
          }.to raise_error ActiveRecord::RecordInvalid
        end
      end
    end
    context "for unauthorised users" do
      it "redirects guests to sign in" do
        post :create, params: {symbolset_id: @symbolset.slug, email: FactoryBot.create(:user).email}
        expect(response).to redirect_to(new_user_session_path)
      end
    
      it "denies the action to Users who are not Collaborators on the Symbolset" do
        sign_in FactoryBot.create(:user)
        post :create, params: {symbolset_id: @symbolset.slug, email: FactoryBot.create(:user).email}
        expect(response).to have_http_status :unauthorized
      end
    end
  end

  describe "DELETE #destroy" do
    context "for Collaborators on the Symbolset" do
      context "with valid parameters" do
        it "successfully deletes the Collaborator" do
          sign_in @symbolset.users.first
          expect{
            delete :destroy, params: {symbolset_id: @symbolset.slug, id: @symbolset.symbolset_users.last.id}
          }.to change(SymbolsetUser, :count).by -1
          @symbolset.reload
          delete :destroy, params: {symbolset_id: @symbolset.slug, id: @symbolset.symbolset_users.last.id}
          expect(response).to redirect_to symbolset_collaborators_path @symbolset
        end
      end
      context "with invalid parameters" do
        context "when the User tries to delete Collaborators from another Symbolset" do
          it "returns unauthorised" do
            @symbolset1 = FactoryBot.create(:symbolset)
            sign_in @symbolset1.symbolset_users.first.user

            @symbolset = FactoryBot.create(:symbolset)
            
            expect(@symbolset.symbolset_users).to_not include(@symbolset1.symbolset_users.first)
            delete :destroy, params: {symbolset_id: @symbolset.slug, id: @symbolset.symbolset_users.first.id}
            expect(response).to have_http_status :unauthorized
          end
        end
        context "when the last collaborator tries to delete themself" do
          it "doesn't delete the collaborator" do
            @symbolset = FactoryBot.create(:symbolset)
            sign_in @symbolset.symbolset_users.first.user
            expect(@symbolset.symbolset_users.count).to be 1
            
            expect{delete :destroy, params: {symbolset_id: @symbolset.slug, id: @symbolset.symbolset_users.first.id}}.to change(SymbolsetUser, :count).by 0
          end
          
          it "redirects back to #index" do
            @symbolset = FactoryBot.create(:symbolset)
            sign_in @symbolset.symbolset_users.first.user
            expect(@symbolset.symbolset_users.count).to be 1
            delete :destroy, params: {symbolset_id: @symbolset.slug, id: @symbolset.symbolset_users.first.id}
            expect(response).to redirect_to symbolset_collaborators_path @symbolset
          end
        end
      end
    end
    context "for unauthorised users" do
      it "redirects guests to sign in" do
        delete :destroy, params: {symbolset_id: @symbolset.slug, id: @symbolset.symbolset_users.first.id}
        expect(response).to redirect_to(new_user_session_path)
      end
    
      it "denies the action to Users who are not Collaborators on the Symbolset" do
        sign_in FactoryBot.create(:user)
        delete :destroy, params: {symbolset_id: @symbolset.slug, id: @symbolset.symbolset_users.first.id}
        expect(response).to have_http_status :unauthorized
      end
    end
  end
end
