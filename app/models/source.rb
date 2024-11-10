class Source < ApplicationRecord

  has_many :labels, inverse_of: :source
  has_many :pictos, inverse_of: :source

  validates_presence_of :name, :slug
  validates_uniqueness_of :slug
  validates :authoritative, inclusion: { in: [true, false] }

end
