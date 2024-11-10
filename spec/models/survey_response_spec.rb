require 'rails_helper'

RSpec.describe SurveyResponse, type: :model do
  context "with valid parameters" do
    it "creates a SurveyResponse object" do
      expect{FactoryBot.create :survey_response}.to_not raise_error
    end
    
    it "creates a SurveyResponse object without a User" do
      response = FactoryBot.create :survey_response
      expect(response.user).to be nil
    end

    it "creates a SurveyResponse object with a User" do
      response = FactoryBot.create :survey_response, :with_user
      expect(response.user).to be_a User
    end
    
    it "allows traversal to Comments" do
      response = FactoryBot.create :survey_response, questions_count: 3, comments_count: 3
      expect(response.comments.count).to be 3
    end
    
    it "returns whether the survey has been completed" do
      incomplete_response = FactoryBot.create :survey_response, comments_count: 1, questions_count: 3
      complete_response = FactoryBot.create :survey_response, comments_count: 3, questions_count: 3

      expect(incomplete_response.comments.count).to be 1
      expect(incomplete_response.survey.survey_pictos.count).to be 3
      
      expect(incomplete_response.is_complete?).to be false
      expect(complete_response.is_complete?).to be true
    end
  end
end
