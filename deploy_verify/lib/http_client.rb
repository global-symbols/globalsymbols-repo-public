# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "stringio"
require "zlib"

module DeployVerify
  # Minimal cookie-aware HTTP client (stdlib only).
  class HttpClient
    attr_reader :last_response, :last_uri

    def initialize(config)
      @config = config
      @cookie_jar = {}
    end

    def get(path, headers: {})
      request(Net::HTTP::Get, path, headers: headers)
    end

    def head(path, headers: {})
      request(Net::HTTP::Head, path, headers: headers)
    end

    def post(path, form: {}, headers: {})
      request(Net::HTTP::Post, path, form: form, headers: headers)
    end

    def patch(path, form: {}, headers: {})
      request(Net::HTTP::Patch, path, form: form, headers: headers)
    end

    def delete(path, headers: {})
      request(Net::HTTP::Delete, path, headers: headers)
    end

    def request(klass, path, form: nil, headers: {}, raw_body: nil, json: nil)
      uri = path.is_a?(URI) ? path : @config.uri(path)
      @last_uri = uri

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = @config.timeout
      http.read_timeout = @config.timeout
      http.write_timeout = @config.timeout if http.respond_to?(:write_timeout=)

      req = klass.new(uri)
      req["User-Agent"] = "DeployVerify/1.0"
      req["Accept"] = "*/*"
      if @config.host_header
        req["Host"] = @config.host_header
      end
      apply_cookies(req)
      headers.each { |k, v| req[k] = v }

      if form
        req.set_form_data(form)
      elsif json
        req["Content-Type"] = "application/json"
        req.body = json.is_a?(String) ? json : JSON.generate(json)
      elsif raw_body
        req.body = raw_body
      end

      res = http.request(req)
      store_cookies(res)
      @last_response = res
      Response.new(res, uri)
    end

    # Follow redirects (GET) up to limit.
    def get_follow(path, limit: 5)
      res = get(path)
      limit.times do
        break unless res.redirect?
        loc = res.headers["location"]
        break if loc.nil? || loc.empty?
        uri = URI.join(res.uri.to_s, loc)
        res = request(Net::HTTP::Get, uri)
      end
      res
    end

    class Response
      attr_reader :raw, :uri

      def initialize(raw, uri)
        @raw = raw
        @uri = uri
      end

      def code
        raw.code.to_i
      end

      def body
        @body ||= decode_body
      end

      def headers
        raw.each_header.to_h
      end

      def success?
        code >= 200 && code < 300
      end

      def redirect?
        code >= 300 && code < 400
      end

      def json
        JSON.parse(body)
      end

      private

      def decode_body
        data = raw.body.to_s
        if raw["content-encoding"].to_s.include?("gzip")
          Zlib::GzipReader.new(StringIO.new(data)).read
        else
          data
        end
      rescue Zlib::GzipFile::Error
        raw.body.to_s
      end
    end

    private

    def apply_cookies(req)
      return if @cookie_jar.empty?
      req["Cookie"] = @cookie_jar.map { |k, v| "#{k}=#{v}" }.join("; ")
    end

    def store_cookies(res)
      # Net::HTTP may return a String or Array for set-cookie
      cookies = res.get_fields("set-cookie") || []
      cookies.each do |c|
        pair = c.split(";").first
        name, value = pair.split("=", 2)
        @cookie_jar[name] = value if name && value
      end
    end
  end
end
