FactoryBot.define do
  factory :picto do
    symbolset
    part_of_speech { :verb }
    source

    transient do
      images_count { 1 }
      labels_count { 1 }
      comments_count { 0 }
      images_file_format { 'png' }
    end

    after :create do |picto, e|
      picto.comments << FactoryBot.create_list(:comment, e.comments_count)
    end
    
    after :build do |picto, e|
      picto.images << FactoryBot.build_list(:image, e.images_count, picto: picto, file_format: e.images_file_format)
      picto.labels << FactoryBot.build_list(:label, e.labels_count, picto: picto)
    end
    
    trait :with_concepts do
      after :create do |picto|
        picto.concepts << FactoryBot.create_list(:concept, 3)
      end
    end
    
    trait :with_published_symbolset do
      association :symbolset, :published
    end
    
    trait :with_survey do
      after :create do |picto|
        survey = FactoryBot.create :survey, symbolset: picto.symbolset
        survey.pictos << picto
      end
    end
  end
end
