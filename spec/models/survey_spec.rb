require 'rails_helper'

RSpec.describe Survey, type: :model do
  context "with valid parameters" do
    before :each do
      @survey = FactoryBot.create :survey
    end
    
    it "creates a Survey within a Symbolset at the 'planning' stage" do
      # survey = FactoryBot.create :survey
      expect(@survey).to be_a Survey
      expect(@survey.symbolset).to be_a Symbolset
      expect(@survey.status).to eq 'planning'
    end
    
    it "creates superseding surveys with the correct symbolset id" do
      # survey = FactoryBot.create :survey
      @survey.create_next_survey(name: 'test')
      expect(@survey.next_survey.symbolset).to eq @survey.symbolset
    end

    it "presents as open_for_feedback only when status is :receiving feedback" do
      expect(@survey.close_at).to be nil # We're not testing the close_at feature in this test.
      
      expect(@survey.status).to eq 'planning'
      expect(@survey.is_open_for_feedback?).to eq false
      
      @survey.update(status: :collecting_feedback)
      expect(@survey.is_open_for_feedback?).to eq true

      @survey.update(status: :analysing_results)
      expect(@survey.is_open_for_feedback?).to eq false

      @survey.update(status: :archived)
      expect(@survey.is_open_for_feedback?).to eq false
    end
    
    it "presents as open_for_feedback before the close_at date" do
      expect(@survey.close_at).to be nil
      
      # No close date
      @survey.update(status: :collecting_feedback)
      expect(@survey.is_open_for_feedback?).to eq true

      # Closing tomorrow
      @survey.update(close_at: Date.today + 1.day)
      expect(@survey.is_open_for_feedback?).to eq true

      # Closing today
      @survey.update(close_at: Date.today)
      expect(@survey.is_open_for_feedback?).to eq true

      # Closing yesterday
      @survey.update(close_at: Date.today - 1.day)
      expect(@survey.is_open_for_feedback?).to eq false
    end
  end
  
  context "with invalid parameters" do
    it "fails validation when created, if status is not 'planning'" do
      expect{FactoryBot.create(:survey, status: :analysing_results)}.to raise_error ActiveRecord::RecordInvalid
    end
  end
  
  context "with multiple surveys" do
    it "orders Surveys by created_at, newest-first" do
      @older_survey = FactoryBot.create :survey
      travel 1.year
      @newer_survey = FactoryBot.create :survey
      
      surveys = Survey.all
      expect(surveys.first).to eq @newer_survey
      expect(surveys.second).to eq @older_survey
    end
  end

  context "with a preceding survey" do
    before :each do
      @survey = FactoryBot.create(:survey, :with_preceding_survey)
    end
    
    it "creates a Survey" do
      expect(@survey).to be_a Survey
    end

    it "allows traversal to the correct preceding Survey" do
      expect(@survey).to be_a Survey
      expect(@survey.previous_survey).to be_a Survey
      expect(@survey.symbolset).to eq @survey.previous_survey.symbolset
    end
    
    it "ensures related Surveys are for the same Symbolset" do
      expect{@survey.save!}.not_to raise_error
      @survey.symbolset = FactoryBot.create :symbolset
      expect{@survey.save!}.to raise_error ActiveRecord::RecordInvalid
    end
  end
  
  context "with Pictos" do
    it "allows traversal to the Pictos and SurveyPictos" do
      survey = FactoryBot.create :survey, pictos_count: 3
      
      expect(survey.pictos.count).to eq 3
      expect(survey.pictos.first).to be_a Picto
      
      expect(survey.survey_pictos.count).to eq 3
      expect(survey.survey_pictos.first).to be_a SurveyPicto
    end
  end
end
