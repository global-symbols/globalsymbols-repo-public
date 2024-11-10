require 'rails_helper'

RSpec.describe SurveyQuestionsController, type: :controller do
  describe "GET #show" do
    context "For surveys that are receiving feedback" do
      it "renders the feedback form" do
        survey = FactoryBot.create(:survey, pictos_count: 3, status_after_create: :collecting_feedback)
        survey_response = FactoryBot.create(:survey_response, survey: survey)
        get :show, params: { survey_id: survey.id, id: 1 }, session: { survey_response_id: survey_response.id }
        expect(response).to have_http_status :success
        expect(response).to render_template('show')
      end
      
      it "renders the feedback form for private pictos" do
        survey = FactoryBot.create(:survey, pictos_count: 1, status_after_create: :collecting_feedback)
        survey.pictos.first.update(visibility: :collaborators)
        survey_response = FactoryBot.create(:survey_response, survey: survey)
        get :show, params: { survey_id: survey.id, id: 1 }, session: { survey_response_id: survey_response.id }
        expect(response).to have_http_status :success
        expect(response).to render_template('show')
        expect(assigns(:picto)).to eq survey.pictos.first
      end
      
      it "redirects to the survey start page if no SurveyResponse is set in session" do
        survey = FactoryBot.create(:survey, pictos_count: 3, status_after_create: :collecting_feedback)

        expect(session[:survey_response_id]).to be_nil
        get :show, params: { survey_id: survey.id, id: 1 }
        expect(response).to redirect_to survey_path(survey)
      end
      
      context "For surveys that are not receiving feedback" do
        it "redirects to the Survey" do
          survey = FactoryBot.create(:survey, pictos_count: 3, status: :planning)
          get :show, params: { survey_id: survey.id, id: 1 }
          expect(response).to redirect_to survey_path(survey)
        end
      end
    end
  end
  
  
  describe "POST #update" do
    context "For surveys that are not receiving feedback" do
      it "redirects to the Survey" do
        survey = FactoryBot.create(:survey, pictos_count: 3, status: :planning)
        
        comment = FactoryBot.create(:comment, :with_survey_response, :with_all_ratings)
        comment.survey_response.survey = survey
        
        post :update, params: { survey_id: comment.survey_response.survey.id, id: 1,  comment: comment.attributes}
        
        expect(response).to redirect_to survey_path(survey)
      end
    end

    context "For surveys that are receiving feedback" do
      it "re-renders the form when provided invalid parameters" do
        survey = FactoryBot.create(:survey, pictos_count: 3, status_after_create: :collecting_feedback)
        survey_response = FactoryBot.create(:survey_response, survey: survey)#, user: @user)
        comment = FactoryBot.create(:comment, :with_all_ratings, survey_response: survey_response)
        
        comment.rating = nil # Makes the comment invalid
    
        post :update, format: :javascript, params: { survey_id: comment.survey_response.survey.id, id: 1,  comment: comment.attributes}, session: { survey_response_id: survey_response.id }

        expect(response).to have_http_status :success
        expect(response).to render_template('update')
      end
      
      it "redirects to the next question when provided valid parameters" do
        survey = FactoryBot.create(:survey, pictos_count: 3, status_after_create: :collecting_feedback)
        survey_response = FactoryBot.create(:survey_response, survey: survey)#, user: @user)
        comment = FactoryBot.create(:comment, :with_all_ratings, survey_response: survey_response)
    
        post :update, format: :javascript, params: { survey_id: survey.id, id: 1,  comment: comment.attributes}, session: { survey_response_id: survey_response.id }
    
        expect(response).to redirect_to survey_question_path(survey, 2)
      end
      
      it "redirects to #thank_you when the last question is reached" do
        # NOTE: This redirect should occur on the final question.
        # NOT when the number of answers matches the number of questions.
        survey = FactoryBot.create(:survey, pictos_count: 3, status_after_create: :collecting_feedback)
        expect(survey.pictos.count).to be 3
        
        survey_response = FactoryBot.create(:survey_response, survey: survey)#, user: @user)
        
        comment = FactoryBot.create(:comment, :with_all_ratings, survey_response: survey_response)
        
        post :update,
             format: :javascript,
             params: { survey_id: survey.id, id: 1, comment: comment.attributes},
             session: { survey_response_id: survey_response.id }
        expect(response).to redirect_to survey_question_path(survey, 2)
        
        post :update,
             format: :javascript,
             params: { survey_id: survey.id, id: 2, comment: comment.attributes},
             session: { survey_response_id: survey_response.id }
        expect(response).to redirect_to survey_question_path(survey, 3)
        
        post :update,
             format: :javascript,
             params: { survey_id: survey.id, id: 3, comment: comment.attributes},
             session: { survey_response_id: survey_response.id }
        expect(response).to redirect_to thank_you_survey_path(survey)
      end
    end
  end
end
