require 'rails_helper'

RSpec.describe Comment, type: :model do
  context "with valid parameters" do
    it "creates a Feedback item on a Picto" do
      expect{FactoryBot.create :comment}.to_not raise_exception
    end

    it "allows traversal to the Picto" do
      picto = FactoryBot.create :picto
      feedback = FactoryBot.create :comment, picto: picto
      expect(feedback.picto).to eq picto
    end

    it "allows traversal to the User" do
      user = FactoryBot.create :user
      feedback = FactoryBot.create :comment, user: user
      expect(feedback.user).to eq user
    end

    it "allows all rating fields to be filled" do
      expect{FactoryBot.create :comment, :with_all_ratings}.to_not raise_exception
    end
    
    context "within a Survey" do
      it "allows traversal to the Survey" do
        # survey_picto = FactoryBot.create :survey_picto, comments_count: 1
        feedback = FactoryBot.create :comment, :with_survey_response, :with_all_ratings
        expect(feedback.survey_response.survey).to be_a Survey
      end
      
      it "requires all ratings fields to be filled" do
        expect{FactoryBot.create :comment, :with_survey_response}.to raise_exception ActiveRecord::RecordInvalid
        expect{FactoryBot.create :comment, :with_survey_response, :with_all_ratings}.to_not raise_exception
        expect{FactoryBot.create :comment, :with_survey_response, :with_all_ratings, contrast_rating: nil}.to raise_exception ActiveRecord::RecordInvalid
      end
    end
  end
  
  context "with invalid attributes" do
    it "fails validation" do
      expect{FactoryBot.create :comment, picto: nil}.to raise_exception ActiveRecord::RecordInvalid

      expect{FactoryBot.create :comment, rating: nil}.to raise_exception ActiveRecord::RecordInvalid

      expect{FactoryBot.create :comment, rating: 6}.to raise_exception ActiveRecord::RecordInvalid

      expect{FactoryBot.create :comment, :with_all_ratings, contrast_rating: 6}.to raise_exception ActiveRecord::RecordInvalid
    end
    
    it "fails validation with a Picto that is not part of the Survey" do
      picto_not_in_survey = FactoryBot.create :picto
      survey_response = FactoryBot.build :survey_response
      
      expect{FactoryBot.create :comment, picto: picto_not_in_survey, survey_response: survey_response}.to raise_exception ActiveRecord::RecordInvalid
    end
  end
end