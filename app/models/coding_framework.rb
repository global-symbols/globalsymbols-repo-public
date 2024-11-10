class CodingFramework < ApplicationRecord
  
  has_many :concepts
  
  validates_presence_of :name, :structure
  validates_presence_of :api_uri_base, if: Proc.new { |ccf| ccf.linked_data? }
  
  validates_uniqueness_of :name
  
  enum structure: [:linked_data, :legacy]
end
