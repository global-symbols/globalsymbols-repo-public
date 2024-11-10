class PictoConcept < ApplicationRecord
  belongs_to :concept, inverse_of: :picto_concepts
  belongs_to :picto, inverse_of: :picto_concepts
  
  validates_presence_of :concept, :picto
  validates_uniqueness_of :concept_id, scope: :picto_id
end
