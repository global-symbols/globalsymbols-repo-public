class Boardbuilder::BoardSet < ApplicationRecord
  has_many :boards, inverse_of: :board_set, foreign_key: 'boardbuilder_board_set_id', dependent: :destroy
  has_many :board_set_users, inverse_of: :board_set, foreign_key: 'boardbuilder_board_set_id', dependent: :destroy
  has_many :users, through: :board_set_users, inverse_of: :boardbuilder_board_sets

  has_many :cells, through: :boards

  accepts_nested_attributes_for :boards

  validates :name, presence: true, length: { maximum: 250 }
  validates :public, inclusion: { in: [true, false] }
  validates :board_set_users, length: { minimum: 1 }

  after_initialize :set_defaults, if: :new_record?

  private
  def set_defaults
    self.public ||= false
  end
end
