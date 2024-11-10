require 'rails_helper'

RSpec.describe SurveyPictoAnalysisController, type: :controller do
  
  before :each do
    @response = FactoryBot.create :survey_response, questions_count: 1, comments_count: 1
    @survey = @response.survey
  end
  
  describe "GET #index" do
    context "for users who are authorised to manage the Symbol Set" do
      it "returns http success" do
        # Sign in as a manager of the Symbol Set
        sign_in @survey.symbolset.users.first
        
        get :index, params: { symbolset_id: @survey.symbolset.friendly_id, survey_id: @survey.id }
        expect(response).to have_http_status(:success)
      end
    end
    
    context "for users not authorised to manage the Symbol Set" do
      it "denies access to signed-in Users who are not managers of the Symbol Set" do
        sign_in FactoryBot.create :user
        get :index, params: { symbolset_id: @survey.symbolset.friendly_id, survey_id: @survey.id }
        expect(response).to have_http_status(:unauthorized)
      end
      it "redirects non-signed-in users to the sign in page" do
        get :index, params: { symbolset_id: @survey.symbolset.friendly_id, survey_id: @survey.id }
        expect(response).to redirect_to new_user_session_path
      end
    end
  end
end
