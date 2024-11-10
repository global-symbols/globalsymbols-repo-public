class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  strip_attributes # Strips whitespace from attributes


  # Finds and returns a translation for the value_key of the enum_name field
  # @param [string] enum_name   name of the enum field
  # @param [string] value_key   value of the enum
  # @return [string]
  def self.human_enum_name(enum_name, value_key)
    I18n.t("activerecord.attributes.#{model_name.i18n_key}.#{enum_name}_options.#{value_key}")
  end
end
