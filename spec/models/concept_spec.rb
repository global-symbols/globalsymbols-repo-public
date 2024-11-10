require 'rails_helper'

RSpec.describe Concept, type: :model do
  context "with minimum parameters" do
    it "creates a Concept" do
      concept = FactoryBot.create(:concept)
      expect(concept).to be_a(Concept)
    end
  end
  
  context "when importing from Conceptnet" do
    before :each do
      @language = FactoryBot.create(:language, iso639_1: 'en')
    end
    
    it "finds, creates and returns a Concept for a valid ConceptNet URI" do
      expect{Concept::find_or_create_by(subject: 'cat', language: @language)}.to change(Concept, :count).by 1
      concept = Concept::find_or_create_by(subject: 'dog', language: @language)
      expect(concept.subject).to eq 'dog'
    end
    
    it "returns an existing Concept if one exists for the requested subject" do
      existing_concept = Concept::find_or_create_by(subject: 'mouse', language: @language)
      found_concept = Concept::find_or_create_by(subject: 'mouse', language: @language)
      expect(found_concept).to eq(existing_concept)
    end
    
    it "fails validation when no matching Concept is found in the DB or ConceptNet" do
      concept = Concept::find_or_create_by(subject: 'fail_concept_does_not_exist', language: @language)
      expect(concept.valid?).to be false
    end
  end
  
  context "with coding_framework or subject missing" do
    it "fails validation" do
      expect{FactoryBot.create(:concept, {coding_framework: nil, subject: nil})}.to raise_error ActiveRecord::RecordInvalid
    end
  end
  
  context "with an existing Concept" do
    it "prevents creation of an identical Concept" do
      concept = FactoryBot.create(:concept)
      # using .dup because .clone copies the ID attribute as well!
      expect{concept.dup.save!}.to raise_error ActiveRecord::RecordInvalid
    end
  end
  
  context "with pictos available" do
    it "allows assignment and traversal to the pictos" do
      concept = FactoryBot.create(:concept, :with_pictos)
      expect(concept.pictos.first).to be_a Picto
      expect(concept.pictos.count).to be > 1
    end
  end
end
