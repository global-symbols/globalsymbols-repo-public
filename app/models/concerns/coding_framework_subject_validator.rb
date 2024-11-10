class CodingFrameworkSubjectValidator < ActiveModel::Validator
  def validate(record)
    # Stop here if no CodingFramework is set.
    return false unless record.coding_framework.present?
    
    uri = URI.escape(record.api_uri)
    
    # Try to find the subject on ConceptNet.
    # If ConceptNet returns an empty result, or 404, add an error to the record.
    begin
      graph = RDF::Graph.load(uri, format: :jsonld)
      raise URI::InvalidURIError unless graph.present?
    rescue URI::InvalidURIError
      record.errors.add :subject, "Subject #{record.subject} does not exist on #{record.coding_framework.name}"
    end
  end
end