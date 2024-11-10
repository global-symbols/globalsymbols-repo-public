class Label < ApplicationRecord
  belongs_to :language, inverse_of: :labels
  belongs_to :picto, inverse_of: :labels
  belongs_to :source, inverse_of: :labels
  
  validates_presence_of :text, :language_id, :picto

  # Each Picto can have only one translation suggestion label.
  validates_uniqueness_of :language_id, scope: [:picto_id, :source_id], if: Proc.new { |label|
    label.source && label.source.slug == 'translation-suggestion'
  }
  
  # One label of each language for a Picto
  # validates_uniqueness_of :language_id, scope: [:picto_id]
  
  # after_create :add_concept_to_picto

  default_scope { joins(:language).order(Arel.sql('IF(FIELD(`languages`.`name`,\'English\')=0,1,0)')).order('languages.name') }

  scope :authoritative, -> { joins(:source).where(sources: {authoritative: :true})}
  scope :suggestion, -> { joins(:source).where(sources: {suggestion: :true})}

  # Tries to add a concept to the Picto for the text of this label
  def add_concept_to_picto
    picto.add_concept(text, language)
  end
end
