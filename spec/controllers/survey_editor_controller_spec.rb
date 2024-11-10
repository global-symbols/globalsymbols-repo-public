require 'rails_helper'

RSpec.describe SurveyEditorController, type: :controller do
  
  describe "GET #export" do
    context "for users who can manage the Symbol Set" do
      it "downloads an Excel file of the Survey data" do
        survey = FactoryBot.create(:survey, pictos_count: 1, responses_count: 2)
        sign_in survey.symbolset.users.first
        get :export, format: :xlsx, params: { symbolset_id: survey.symbolset, id: survey.id }
        
        expect(response).to be_successful
        expect(response.headers['Content-Disposition']).to include 'attachment'
        expect(response.headers['Content-Type']).to include 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      end
    end
  end
  
  describe "Add/remove Pictos from Surveys" do
    before(:each) do
      @referrer = '/symbolsets/1/symbol'
      request.env["HTTP_REFERER"] = @referrer
      
      # Creates a Picto, Survey and User. The Picto will not be part of the Survey.
      @picto = FactoryBot.create(:picto)
      @survey = FactoryBot.create(:survey, symbolset: @picto.symbolset)
      
      @user = FactoryBot.create(:user)
      @picto.symbolset.users << @user
    end
    
    describe "POST #add_symbol" do
      context "for users who can manage the Symbol Set" do
        it "adds the symbol to the survey and redirects :back" do
          sign_in @user
          expect{
            post :add_symbol, params: { symbolset_id: @picto.symbolset, id: @survey.id, symbol_id: @picto.id }
          }.to change(@survey.pictos, :count).by 1
    
          expect(@survey.pictos).to include(@picto)
    
          expect(response).to redirect_to @referrer
        end
      end

      context "for users not authorised on the Symbol Set" do
        it "shows logged-in users an unauthorised message" do
          sign_in FactoryBot.create :user
          expect{
            post :add_symbol, params: { symbolset_id: @picto.symbolset, id: @survey.id, symbol_id: @picto.id }
          }.to change(@survey.pictos, :count).by 0
    
          expect(response).to have_http_status :unauthorized
        end
        
        it "redirects anonymous users to the login page" do
          expect{
            post :add_symbol, params: { symbolset_id: @picto.symbolset, id: @survey.id, symbol_id: @picto.id }
          }.to_not change(@survey.survey_pictos, :count)
          
          expect(response).to redirect_to new_user_session_path
        end
      end
    end
    
    describe "POST #remove_symbol" do
      context "for users who can manage the Symbol Set" do
        it "removes the picto_symbol from the survey and redirects to the Survey" do
          sign_in @user
          
          # Add the Picto to the Survey
          @survey.pictos << @picto
    
          survey_picto = @survey.survey_pictos.first
    
    
          expect{
            post :remove_symbol, params: { symbolset_id: @picto.symbolset, id: @survey.id, survey_picto_id: survey_picto.id }
          }.to change(@survey.survey_pictos, :count).by -1
    
          expect(response).to redirect_to symbolset_survey_path survey_picto.survey.symbolset, survey_picto.survey
        end
      end
      
      context "for users not authorised on the Symbol Set" do
        it "shows logged-in users an unauthorised message" do
          sign_in FactoryBot.create :user
          @survey.pictos << @picto
    
          survey_picto = @survey.survey_pictos.first
    
          expect{
            post :remove_symbol, params: { symbolset_id: @picto.symbolset, id: @survey.id, survey_picto_id: survey_picto.id }
          }.to_not change(@survey.survey_pictos, :count)
          expect(response).to have_http_status :unauthorized
        end
        
        it "redirects anonymous users to the login page" do
          @survey.pictos << @picto
  
          survey_picto = @survey.survey_pictos.first
          
          expect{
            post :remove_symbol, params: { symbolset_id: @picto.symbolset, id: @survey.id, survey_picto_id: survey_picto.id }
          }.to_not change(@survey.survey_pictos, :count)
          expect(response).to redirect_to new_user_session_path
        end
      end
    end
  end
end

