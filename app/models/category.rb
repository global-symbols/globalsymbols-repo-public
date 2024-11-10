class Category < ApplicationRecord
  belongs_to :concept, inverse_of: :categories
  has_many :pictos, inverse_of: :category
  
  validates_presence_of :name
  validates_uniqueness_of :name, :concept_id
end
