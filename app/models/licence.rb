class Licence < ApplicationRecord
  has_many :symbolsets, inverse_of: :licence
  
  validates_presence_of :name
  
  validates_uniqueness_of :name
  validates_uniqueness_of :url, allow_blank: true
end
