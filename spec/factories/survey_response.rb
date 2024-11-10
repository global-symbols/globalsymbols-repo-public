FactoryBot.define do
  factory :survey_response do
    survey { FactoryBot.create :survey }
    
    trait :with_user do
      user { FactoryBot.create :user }
    end
    
    transient do
      questions_count { 0 }
      comments_count { 0 }
    end
    
    before :create do |survey_response, e|
      raise "The number of comments cannot be greater than the number of questions" if e.comments_count > e.questions_count
    end
    
    after :create do |survey_response, e|
      # Populate questions up to question_count
      survey_response.survey.survey_pictos << FactoryBot.create_list(:survey_picto, e.questions_count, survey: survey_response.survey)
      
      # Populate responses up to comment_count
      survey_response.survey.survey_pictos.take(e.comments_count).each do |sp|
        survey_response.comments << FactoryBot.create(:comment, :with_all_ratings, picto: sp.picto)
      end
    end
  end
end
