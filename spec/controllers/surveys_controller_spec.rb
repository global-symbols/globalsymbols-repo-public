require 'rails_helper'

RSpec.describe SurveysController, type: :controller do

  before :each do
    @survey = FactoryBot.create :survey
  end
  
  describe "GET #show" do
    context "for all users" do
      it "returns http success and renders the template" do
        get :show, params: {id: @survey.id}
        expect(response).to have_http_status :success
        expect(response).to render_template 'show'
      end
    end
  end

  describe "GET #print" do
    context "for all users" do
      it "returns http success and renders the template" do
        get :print, params: {id: @survey.id}
        expect(response).to have_http_status :success
        expect(response).to render_template 'print'
      end
    end
  end

  describe "GET #thank_you" do
    context "for all users" do
      it "returns http success and renders the template" do
        get :thank_you, params: {id: @survey.id}
        expect(response).to have_http_status :success
        expect(response).to render_template 'thank_you'
      end
      it "clears the SurveyResponse ID stored in the session" do
        # First, store the session var
        post :create_response, params: { id: @survey.id, survey_response:  {name: nil}}, format: :js
        expect(session[:survey_response_id]).to eq assigns(:response).id
        
        # Call thank_you and ensure the session var is cleared
        get :thank_you, params: {id: @survey.id}
        expect(session[:survey_response_id]).to be_nil
      end
    end
  end
  
  describe "POST #create_response" do
    context "for all users" do
      it "creates a new SurveyResponse, with respondent details" do
        expect {
          post :create_response, params: { id: @survey.id, survey_response:  {name: 'Joe Bloggs', organisation: 'Joe Co', role: 'MD'}}, format: :js
        }.to change(SurveyResponse, :count).by 1
        
        # Check the name and org were set
        expect(SurveyResponse.last.name). to eq 'Joe Bloggs'
        expect(SurveyResponse.last.organisation). to eq 'Joe Co'
        expect(SurveyResponse.last.role). to eq 'MD'
      end
      it "creates a new SurveyResponse, without respondent details" do
        expect {
          post :create_response, params: { id: @survey.id, survey_response:  {name: nil, organisation: nil}}, format: :js
        }.to change(SurveyResponse, :count).by 1
      end
      
      it "redirects to the first question" do
        post :create_response, params: { id: @survey.id, survey_response:  {name: nil, organisation: nil}}, format: :js
        expect(response).to redirect_to survey_question_path(@survey, 1)
      end
      
      it "sets a session variable of the SurveyResponse ID" do
        post :create_response, params: { id: @survey.id, survey_response:  {name: nil, organisation: nil}}, format: :js
        expect(session[:survey_response_id]).to eq assigns(:response).id
      end
    end
  end
end
