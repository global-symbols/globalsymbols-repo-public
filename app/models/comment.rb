class Comment < ApplicationRecord
  belongs_to :picto, inverse_of: :comments
  belongs_to :user, inverse_of: :comments, optional: true
  belongs_to :survey_response, optional: true, inverse_of: :comments
  has_one :survey, through: :survey_picto
  
  # The rating field must always be filled with a number 1-5.
  validates :rating, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5, message: "can't be blank" }, allow_nil: false

  # Other rating fields must be filled with a number 1-5, and are optional.
  validates :representation_rating, :contrast_rating, :cultural_rating, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true
  
  # Other rating fields are required when this is part of a survey_response
  validates :representation_rating, :contrast_rating, :cultural_rating, presence: true, if: :survey_response
end
