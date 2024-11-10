class Boardbuilder::BoardSetUser < ApplicationRecord
  belongs_to :board_set, inverse_of: :boards, foreign_key: 'boardbuilder_board_set_id'
  belongs_to :user, inverse_of: :boardbuilder_board_set_users, foreign_key: 'user_id'

  enum role: [:editor, :owner]

  validates_presence_of :board_set, :user, :role
  validates_uniqueness_of :board_set, scope: :user

  after_initialize :set_default_role, if: :new_record?

  private
  def set_default_role
    self.role ||= :owner
  end
end
