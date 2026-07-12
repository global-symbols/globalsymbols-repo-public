class CodingFrameworkSubjectValidator < ActiveModel::Validator
  def validate(record)
    # Stop here if no CodingFramework is set.
    return false unless record.coding_framework.present?

    uri = URI.escape(record.api_uri)

    # Try to find the subject on ConceptNet.
    # If ConceptNet returns an empty result, or 404, add an error to the record.
    # Network/upstream failures (502, timeout, etc.) become a soft validation error
    # so the user sees a message instead of a 500.
    begin
      graph = RDF::Graph.load(uri, format: :jsonld)
      raise URI::InvalidURIError unless graph.present?
    rescue URI::InvalidURIError
      record.errors.add :subject, "Subject #{record.subject} does not exist on #{record.coding_framework.name}"
    rescue *network_errors => e
      Rails.logger.warn(
        "[CodingFrameworkSubjectValidator] #{record.coding_framework.name} unavailable " \
        "for subject=#{record.subject.inspect}: #{e.class}: #{e.message}"
      )
      record.errors.add(
        :base,
        :coding_framework_unavailable,
        framework: record.coding_framework.name
      )
    end
  end

  private

  def network_errors
    errors = [
      IOError,
      SocketError,
      Timeout::Error,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::ETIMEDOUT,
      Errno::EHOSTUNREACH,
      Errno::ENETUNREACH
    ]
    errors << Net::OpenTimeout if defined?(Net::OpenTimeout)
    errors << Net::ReadTimeout if defined?(Net::ReadTimeout)
    errors << OpenURI::HTTPError if defined?(OpenURI::HTTPError)
    errors
  end
end
