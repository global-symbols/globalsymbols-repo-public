class Picto < ApplicationRecord
  belongs_to :symbolset
  belongs_to :category, inverse_of: :pictos, optional: true
  belongs_to :source, inverse_of: :pictos

  has_many :cells, inverse_of: :picto
  has_many :comments, inverse_of: :picto
  has_many :images, inverse_of: :picto, dependent: :destroy
  has_many :labels, inverse_of: :picto, dependent: :destroy
  has_many :picto_concepts, dependent: :destroy, inverse_of: :picto
  has_many :concepts, through: :picto_concepts, inverse_of: :pictos
  has_many :survey_pictos, inverse_of: :picto
  has_many :surveys, through: :survey_pictos, inverse_of: :pictos

  accepts_nested_attributes_for :images
  accepts_nested_attributes_for :labels

  enum :part_of_speech, [:noun, :verb, :adjective, :adverb, :pronoun, :preposition, :conjunction, :interjection, :article, :modifier]

  enum :visibility, { everybody: 0, collaborators: 1 }

  after_initialize :set_defaults, :if => :new_record?
  
  validates_associated :images, :labels
  validates :images, length: { minimum: 1 }
  validates :labels, length: { minimum: 1 }
  
  validates_presence_of :symbolset, :visibility
  
  scope :without_concepts, -> {left_outer_joins(:concepts).where(concepts: { id: nil })}
  scope :published, -> { joins(:symbolset).where(symbolsets: {status: :published})}
  
  # @param  text           The string to add as a concept
  # @param  language       The Language of @text
  def add_concept(text, language)
    begin
      # Try to create the Concept and add it to the Picto
      concept = Concept.find_or_create_by!(subject: text, language: language)
      picto_concepts.create(concept: concept)

    # If no matching Concept is found in the CodingFramework, a ValidationError will be raised.
    rescue ActiveRecord::RecordInvalid => e
      # ConceptNet (or other coding framework) is down — don't retry; let the controller show a clear message.
      if coding_framework_unavailable_error?(e)
        raise
      end

      # Try some adjustments if the text is in English
      if language.iso639_1 == 'en'
        if text =~ /\d+\w?$/
          #   If the label has a number at the end, try again without the number
          #   For instance, where we have labels like Computer 1, Computer 2, etc.
          add_concept(text.gsub(/\d+\w?$/, '').strip, language)

        elsif text =~ / ?, To$/
          #   If the label has ', To' at the end, try again without this part
          #   For instance, where we have labels like 'Brush Teeth, To', etc.
          add_concept(text.gsub(/ ?, To$/, '').strip, language)

        elsif text =~ / ?\([\w ]+\)$/
          #   If the label has anything in parentheses at the end, try again without this part
          #   For instance, where we have labels like 'Mother (International version)', try 'Mother' etc.
          add_concept(text.gsub(/ ?\([\w ]+\)$/, '').strip, language)
        end
      end
    end
  end
  
  def alternative_pictos
    Picto.joins(:concepts).where(concepts: {id: concepts}).where.not(id: id).distinct
  end
  
  # Returns the Label matching the supplied language code.
  # Prefers authoritative labels; falls back to any label for that language, then any label.
  # Returns nil only when the picto has no labels at all.
  def best_label_for(language)
    if language.is_a?(String) || language.is_a?(Symbol)
      # I18n locales may be "en" or "en-GB"; labels store iso639_1 as two-letter codes.
      iso = language.to_s.split(/[-_]/).first
      labels.authoritative.where(languages: { iso639_1: iso }).first ||
        labels.authoritative.first ||
        labels.where(languages: { iso639_1: iso }).first ||
        labels.first
    else
      labels.authoritative.where(language: language).first ||
        labels.authoritative.first ||
        labels.where(language: language).first ||
        labels.first
    end
  end
  
  private

  def coding_framework_unavailable_error?(error)
    error.record.errors.details[:base]&.any? { |d| d[:error] == :coding_framework_unavailable }
  end

  def set_defaults
    self.archived ||= false
    self.visibility ||= :everybody
  end
end
