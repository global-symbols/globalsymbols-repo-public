class CsvMissingRequiredValuesException < Exception
  def initialize(data)
    @data = data
  end
end