class Language < ApplicationRecord
  belongs_to :macrolanguage, -> { where active: true }, foreign_key: :language_id, class_name: 'Language', optional: true, inverse_of: :languages
  has_many :concepts, inverse_of: :language
  has_many :languages, inverse_of: :macrolanguage
  has_many :labels, inverse_of: :picto
  has_many :surveys, inverse_of: :language
  has_many :users, inverse_of: :language
  
  validates_uniqueness_of :name, :iso639_3
  validates_presence_of :name, :iso639_3, :scope, :category
  
  # Default scope is Living and Constructed Languages, ORDERing with English first, then alphabetically by name
  default_scope { where(category: ['L', 'C']).order(Arel.sql('IF(FIELD(`name`,\'English\')=0,1,0)')).order(:name) }
  
  # @return The iso639_1 code of this language. If no iso639_1 code is present, try to return the iso639_1 code of the associated macrolanguage.
  def iso639_1_or_macrolanguage_code
    iso639_1 || self.try(:macrolanguage).try(:iso639_1)
  end

  def iso639_1_or_3_code
    iso639_1 || iso639_3
  end

  # Adapts the ISO639-1 code to a code that's compatible with the Azure Translator
  def azure_code
    case iso639_1
    when 'zh'   # Chinese
      'zh-Hans' # Simplified Chinese
    when 'sr'   # Serbian
      'sr-Cyrl' # Cyrillic Serbian
    else
      iso639_1
    end
  end
  
  private
    def set_defaults
      self.active ||= false
    end
end
