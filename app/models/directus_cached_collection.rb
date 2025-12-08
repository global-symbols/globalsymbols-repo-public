# frozen_string_literal: true

class DirectusCachedCollection < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :parameter_sets, presence: true

  # Handle JSON serialization for parameter_sets since we're using text column
  serialize :parameter_sets, JSON

  # Scopes for efficient querying
  scope :active, -> { where(active: true) }
  scope :ordered_by_priority, -> { order(priority: :desc, name: :asc) }

  # Class methods to replicate current constant behavior
  def self.cached_collection_names
    active.pluck(:name)
  end

  def self.collection_params_map
    active.each_with_object({}) do |collection, hash|
      hash[collection.name] = collection.parameter_sets.map(&:symbolize_keys)
    end
  end

  # Instance methods for parameter_sets handling
  def parameter_sets=(value)
    write_attribute(:parameter_sets, value.is_a?(Array) ? value : (value.present? ? [value] : []))
  end

  def parameter_sets
    value = read_attribute(:parameter_sets)
    value.present? ? value : []
  end
end
