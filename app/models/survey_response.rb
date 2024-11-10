class SurveyResponse < ApplicationRecord
  belongs_to :survey, inverse_of: :responses
  belongs_to :user, inverse_of: :survey_responses, required: false
  
  has_many :comments, inverse_of: :survey_response, dependent: :destroy
  
  accepts_nested_attributes_for :comments
  
  before_validation :set_user_on_comments, on: :create
  
  validates_presence_of :survey
  
  def is_complete?
    comments.count == survey.survey_pictos.count
  end
  
  def percent_complete
    comments.count / survey.survey_pictos.count * 100
  end
  
  private
  def set_user_on_comments
    comments.each do |comment|
      comment.user = user
    end
  end
end
