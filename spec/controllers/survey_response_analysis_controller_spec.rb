require 'rails_helper'

RSpec.describe SurveyResponseAnalysisController, type: :controller do
  
  before :each do
    @response = FactoryBot.create :survey_response, questions_count: 1, comments_count: 1
    @survey = @response.survey
  end
  
  describe "GET #index" do
    context "for users who are authorised to manage the Symbol Set" do
      it "returns http success" do
        # Sign in as a manager of the Symbol Set
        sign_in @survey.symbolset.users.first
        
        get :index, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id }
        expect(response).to have_http_status(:success)
      end
    end
    
    context "for users not authorised to manage the Symbol Set" do
      it "denies access to signed-in Users who are not managers of the Symbol Set" do
        sign_in FactoryBot.create :user
        get :index, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id }
        expect(response).to have_http_status(:unauthorized)
      end
      it "redirects non-signed-in users to the sign in page" do
        get :index, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id }
        expect(response).to redirect_to new_user_session_path
      end
    end
  end
  
  describe "GET #show" do
    context "for users who are authorised to manage the Symbol Set" do
      it "returns http success" do
        # Sign in as a manager of the Symbol Set
        sign_in @survey.symbolset.users.first
        
        get :show, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id, id: @response.id }
        expect(response).to have_http_status(:success)
      end
    end
    
    context "for users not authorised to manage the Symbol Set" do
      it "denies access to signed-in Users who are not managers of the Symbol Set" do
        sign_in FactoryBot.create :user
        get :show, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id, id: @response.id }
        expect(response).to have_http_status(:unauthorized)
      end
      it "redirects non-signed-in users to the sign in page" do
        get :show, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id, id: @response.id }
        expect(response).to redirect_to new_user_session_path
      end
    end
  end
  
  describe "GET #new" do
    context "for users who are authorised to manage the Symbol Set" do
      before :each do
        # Sign in as a manager of the Symbol Set
        sign_in @survey.symbolset.users.first
      end
      it "returns http success" do
        get :new, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id }
        expect(response).to have_http_status(:success)
      end

      it "assigns the survey" do
        get :new, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id }
        expect(assigns(:survey)).to eq @survey
      end
    end

    context "for users not authorised to manage the Symbol Set" do
      it "denies access to signed-in Users who are not managers of the Symbol Set" do
        sign_in FactoryBot.create :user
        get :new, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id }
        expect(response).to have_http_status(:unauthorized)
      end
      it "redirects non-signed-in users to the sign in page" do
        get :new, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id }
        expect(response).to redirect_to new_user_session_path
      end
    end
  end

  describe "GET #create" do
    before :each do
      @participant = FactoryBot.create(:user)
      
      @response2 = FactoryBot.build(:survey_response, survey: @survey, user: @participant)
      @response_params = @response2.attributes.except('id', 'updated_at', 'created_at')
      @response_params["comments_attributes"] = [ @response.comments.first.dup.attributes.except('id', 'survey_response_id', 'user_id', 'read', 'resolved', 'updated_at', 'created_at') ]
      # @response_params["comments_attributes"][0]['user_id'] = @participant.id
      puts @response_params
    end
    
    context "for users who are authorised to manage the Symbol Set" do
      before :each do
        # Sign in as a manager of the Symbol Set
        sign_in @survey.symbolset.users.first
      end
      
      it "saves the response" do
        expect {
          post :create, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id, response: @response_params }
        }.to change(SurveyResponse, :count).by 1
      end
    
      it "assigns the survey" do
        post :create, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id, response: @response_params }
        expect(assigns(:survey)).to eq @survey
      end
    end
  
    context "for users not authorised to manage the Symbol Set" do
      it "denies access to signed-in Users who are not managers of the Symbol Set" do
        sign_in FactoryBot.create :user
        post :create, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id, response: @response_params }
        expect(response).to have_http_status(:unauthorized)
      end
      it "redirects non-signed-in users to the sign in page" do
        post :create, params: { symbolset_id: @survey.symbolset, survey_id: @survey.id, response: @response_params }
        expect(response).to redirect_to new_user_session_path
      end
    end
  end
end
