class Survey < ApplicationRecord
  belongs_to :language, inverse_of: :surveys, optional: true
  belongs_to :symbolset, default: -> { previous_survey.symbolset if previous_survey.present? }
  
  has_one :next_survey, class_name: :Survey, foreign_key: :previous_survey_id, inverse_of: :previous_survey
  belongs_to :previous_survey, class_name: :Survey, optional: true, inverse_of: :next_survey

  has_many :survey_pictos, inverse_of: :survey, dependent: :destroy
  has_many :pictos, through: :survey_pictos, inverse_of: :surveys
  has_many :responses, class_name: :SurveyResponse, inverse_of: :survey, dependent: :destroy
  
  validates :name, presence: true
  validates :status, presence: true
  validate :status_must_be_draft, on: :create
  validate :related_surveys_have_same_symbolset
  
  enum status: [:planning, :collecting_feedback, :analysing_results, :archived]
  
  after_initialize :set_defaults, if: :new_record?

  default_scope { order(created_at: :desc) }
  
  # Is this Survey open for feedback?
  def is_open_for_feedback?
    # If the close_at date is set and has passed, then no
    return false if close_at.present? and close_at < Date.today
    # Otherwise, check whether the status is :collecting_feedback
    status == 'collecting_feedback'
  end

  private
    def set_defaults
      self.status ||= :planning
    end

    def status_must_be_draft
      errors.add(:status, "must be 'planning' for new Surveys") if status != 'planning'
    end
  
    def related_surveys_have_same_symbolset
      errors.add(:symbolset, "must be the same as the previous survey") if previous_survey.present? and previous_survey.symbolset != symbolset
      errors.add(:symbolset, "must be the same as the next survey") if next_survey.present? and next_survey.symbolset != symbolset
    end
end
