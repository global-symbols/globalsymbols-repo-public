require 'rails_helper'

RSpec.describe "survey_questions/show.html.haml", type: :view do
  before :each do
    @english_label = FactoryBot.build(
        :label,
        text: 'English label text adkjfa',
        description: 'English label description ksjdhfgkaslefb',
        language: Language.find_by(iso639_1: :en)
    )
    
    @french_label = FactoryBot.build(
        :label,
        text: 'French label text kjshdflskases',
        language: Language.find_by(iso639_1: :fr)
    )

    @picto = FactoryBot.build(:picto, labels_count: 0, labels: [ @english_label, @french_label])
    
    @survey = FactoryBot.create(
        :survey,
        status_after_create: :collecting_feedback,
        pictos: [@picto]
    )
    
    @survey_response = FactoryBot.create(:survey_response, survey: @survey)

    assign(:survey, @survey)
    assign(:survey_response, @survey_response)
    assign(:question, 1)
    assign(:picto, @picto)
    assign(:feedback, @survey_response.comments.find_or_initialize_by(picto: @picto))
  end
  
  it 'does not display symbol descriptions when Survey.show_symbol_descriptions is false' do
    expect(@survey.show_symbol_descriptions).to be_falsey # false or nil
    render template: "survey_questions/show.html.haml"
    expect(rendered).to_not include @picto.labels.first.description
  end

  it 'displays symbol descriptions when Survey.show_symbol_descriptions is true' do
    @survey.update!(show_symbol_descriptions: true)
    render template: "survey_questions/show.html.haml"
    expect(rendered).to include @picto.labels.first.description
  end
  
  context 'with pictos that have labels in multiple languages' do

    it 'displays labels in all Languages when Survey.language is empty' do
      render template: "survey_questions/show.html.haml"
      expect(rendered).to include @english_label.text
      expect(rendered).to include @french_label.text
    end

    it 'displays labels in the specified Language when Survey.language is set' do
      puts @english_label.text
      @survey.update!(language: @french_label.language)
      render template: "survey_questions/show.html.haml"
      expect(rendered).to_not include @english_label.text
      expect(rendered).to include @french_label.text
    end
  end
end
