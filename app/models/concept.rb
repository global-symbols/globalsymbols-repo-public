class Concept < ApplicationRecord
  
  belongs_to :coding_framework, inverse_of: :concepts
  belongs_to :language, inverse_of: :concepts
  has_many :categories, inverse_of: :concept
  has_many :picto_concepts, inverse_of: :concept
  has_many :pictos, through: :picto_concepts, inverse_of: :concepts

  # Sets the default CodingFramework on new records ()while we have just one CodingFramework).
  attribute :coding_framework_id, :integer, default: CodingFramework.first.id
  
  validates_presence_of :coding_framework, :subject, :language
  validates_uniqueness_of :subject, scope: [:language_id, :coding_framework_id]
  validates_with CodingFrameworkSubjectValidator
  
  # Always set the subject to a URL parameterised version
  before_validation :parameterise_subject

  # default_scope { joins(:language).order(Arel.sql('IF(FIELD(`languages`.`name`,\'English\')=0,1,0)')).order('languages.name').order(:subject) }
  
  def api_uri
    false if coding_framework.api_uri_base.nil?
    coding_framework.api_uri_base % {subject: self.subject, language: self.language.iso639_1}
  end

  def www_uri
    false if coding_framework.www_uri_base.nil?
    coding_framework.www_uri_base % {subject: self.subject, language: self.language.iso639_1}
  end
  
  protected
    
    def parameterise_subject
      subject.downcase.strip.gsub!(' ', '_') unless subject.nil?
    end
end