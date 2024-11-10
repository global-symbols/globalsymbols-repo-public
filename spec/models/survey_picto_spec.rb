require 'rails_helper'

RSpec.describe SurveyPicto, type: :model do
  context "with valid parameters" do
    it "validates and creates a SurveyPicto" do
      survey_picto = FactoryBot.create(:survey_picto)
      expect(survey_picto).to be_a SurveyPicto
    end
    
    it "returns the correct records when traversing to Survey or Picto" do
      picto = FactoryBot.create(:picto)
      survey = FactoryBot.create(:survey, symbolset: picto.symbolset)
      survey_picto = FactoryBot.create(:survey_picto, survey: survey, picto: picto)
      expect(survey_picto.survey).to be(survey)
      expect(survey_picto.picto).to be(picto)
    end

    it "allows adding Pictos from different Symbolsets" do
      survey = FactoryBot.create :survey
      picto = FactoryBot.create :picto
      expect(survey.symbolset).to_not eq picto.symbolset
      expect{survey.pictos << picto}.to_not raise_error
    end
  end
  
  context "with invalid parameters" do
    it "fails validation" do
      expect{FactoryBot.create(:survey_picto, survey: nil)}.to raise_error ActiveRecord::RecordInvalid
      expect{FactoryBot.create(:survey_picto, picto: nil)}.to raise_error ActiveRecord::RecordInvalid
    end
    
    it "prevents creation of duplicate SurveyPictos" do
      sp = FactoryBot.create(:survey_picto)
      expect{FactoryBot.create(:survey_picto, survey: sp.survey, picto: sp.picto)}.to raise_error ActiveRecord::RecordInvalid
    end
  end
end
