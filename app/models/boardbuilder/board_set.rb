class Boardbuilder::BoardSet < ApplicationRecord
  has_many :boards, inverse_of: :board_set, foreign_key: 'boardbuilder_board_set_id', dependent: :destroy
  has_many :board_set_users, inverse_of: :board_set, foreign_key: 'boardbuilder_board_set_id', dependent: :destroy
  has_many :users, through: :board_set_users, inverse_of: :boardbuilder_board_sets

  has_many :cells, through: :boards

  belongs_to :thumbnail, class_name: 'Boardbuilder::Media', optional: true

  accepts_nested_attributes_for :boards, :thumbnail

  validates :name, presence: true, length: { maximum: 250 }
  validates :public, inclusion: { in: [true, false] }
  validates :board_set_users, length: { minimum: 1 }

  validates :description, length: { maximum: 1000 }
  validates :tags, length: { maximum: 10 }
  validates :lang, length: { maximum: 2 }
  validates :author, length: { maximum: 100 }
  validates :author_url, format: { with: URI::regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  after_initialize :set_defaults, if: :new_record?

  private
  def set_defaults
    self.public ||= false
  end
end
