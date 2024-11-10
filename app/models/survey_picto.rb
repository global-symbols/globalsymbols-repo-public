class SurveyPicto < ApplicationRecord
  belongs_to :survey, inverse_of: :survey_pictos
  belongs_to :picto, inverse_of: :survey_pictos
  
  validates_presence_of :survey, :picto
  validates_uniqueness_of :picto, scope: :survey
end
