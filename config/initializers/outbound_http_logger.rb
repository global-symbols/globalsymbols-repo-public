require 'json'
require 'logger'
require 'time'

outbound_http_log_path = Rails.root.join('log', 'outbound_http.log')
outbound_http_logger = ActiveSupport::Logger.new(outbound_http_log_path, 10, 20.megabytes)

outbound_http_logger.formatter = proc do |severity, time, _progname, msg|
  payload =
    if msg.is_a?(Hash)
      msg
    elsif msg.is_a?(String)
      { message: msg }
    else
      { message: msg.to_s }
    end

  payload[:severity] = severity
  payload[:timestamp] = time.utc.iso8601(3)

  "#{payload.to_json}\n"
end

Rails.configuration.x.outbound_http_logger = outbound_http_logger
