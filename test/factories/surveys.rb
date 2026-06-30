FactoryBot.define do
  factory :survey do
    symbolset
    sequence(:name) { |n| n }
    introduction { 'Thanks for taking this survey' }
    
    trait :with_preceding_survey do
      before :create do |survey|
        last_survey = FactoryBot.create(:survey)
        survey.symbolset = last_survey.symbolset
        survey.previous_survey = last_survey
      end
    end
    
    transient do
      pictos_count { 0 }
      responses_count { 0 }
      status_after_create { nil } # Sets the Survey.status after creation, because new Surveys must have a state of :planning
    end
    
    after :create do |survey, e|
      # Create pictos.
      survey.pictos << FactoryBot.create_list(:picto, e.pictos_count, symbolset_id: survey.symbolset.id)

      # Populate responses up to responses_count. Each response should have pictos_count comments
      e.responses_count.times do
        response = FactoryBot.create(:survey_response, :with_user, survey: survey)
        survey.pictos.each do |picto|
          response.comments << FactoryBot.create(:comment, :with_all_ratings, picto: picto)
        end
      end
      
      # Update the Survey.status if requested.
      survey.update(status: e.status_after_create) unless e.status_after_create.nil?
    end
  end
end