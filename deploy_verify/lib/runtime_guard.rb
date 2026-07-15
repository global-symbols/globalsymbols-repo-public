# frozen_string_literal: true

require "socket"
require "net/http"
require "uri"

module DeployVerify
  # Ensures a suite only runs on its intended server (not a laptop / wrong env).
  class RuntimeGuard
    class WrongEnvironment < StandardError; end

    # Private IPs for target hosts (topology). Override with DEPLOY_VERIFY_ALLOWED_IPS.
    PRE_PROD_IPS = %w[172.31.30.149].freeze
    # Old prod Rails (t2) until cutover; new Kamal prod is m7g.
    PROD_IPS = %w[172.31.6.238 172.31.5.122].freeze

    def self.assert!(profile)
      new(profile).assert!
    end

    def initialize(profile)
      @profile = profile.to_s
    end

    def assert!
      errors = []

      ips = local_ipv4_addresses
      allowed = allowed_ips_for_profile

      unless ips.intersect?(allowed)
        errors << "host IPs #{ips.inspect} not in allowlist for #{@profile}: #{allowed.inspect}"
      end

      case @profile
      when "pre_prod"
        if rails_env && rails_env != "pre-prod"
          errors << "RAILS_ENV=#{rails_env.inspect} (want pre-prod)"
        end
        if kamal_destination && kamal_destination != "pre-prod"
          errors << "KAMAL_DESTINATION=#{kamal_destination.inspect} (want pre-prod)"
        end
        if looks_like_developer_laptop?(ips)
          errors << "refusing to run on a developer workstation"
        end
      when "prod"
        if rails_env && %w[pre-prod development test].include?(rails_env)
          errors << "RAILS_ENV=#{rails_env.inspect} is not production"
        end
        if kamal_destination && kamal_destination != "production" && kamal_destination != "prod"
          # allow unset on host; if set must be production
          errors << "KAMAL_DESTINATION=#{kamal_destination.inspect} (want production)"
        end
        if looks_like_developer_laptop?(ips)
          errors << "refusing to run on a developer workstation"
        end
      end

      return if errors.empty?

      raise WrongEnvironment, <<~MSG
        Deploy verify [#{@profile}] blocked — wrong runtime environment:
          #{errors.map { |e| "- #{e}" }.join("\n  ")}
          hostname=#{Socket.gethostname}
          This suite must run on the #{@profile} app server (or inside its web container), not from a laptop or other host.
          Override allowlist only if intentional: DEPLOY_VERIFY_ALLOWED_IPS=x.x.x.x
      MSG
    end

    private

    def allowed_ips_for_profile
      if ENV["DEPLOY_VERIFY_ALLOWED_IPS"].to_s.strip != ""
        return ENV["DEPLOY_VERIFY_ALLOWED_IPS"].split(/[,\s]+/).map(&:strip).reject(&:empty?)
      end
      @profile == "pre_prod" ? PRE_PROD_IPS.dup : PROD_IPS.dup
    end

    def local_ipv4_addresses
      ips = Socket.ip_address_list.select { |a| a.ipv4? && !a.ipv4_loopback? }.map(&:ip_address)
      # Prefer EC2 metadata private IP when available (IMDSv2)
      meta = ec2_private_ip
      ips << meta if meta && !ips.include?(meta)
      ips.uniq
    end

    def ec2_private_ip
      token_uri = URI("http://169.254.169.254/latest/api/token")
      http = Net::HTTP.new(token_uri.host, token_uri.port)
      http.open_timeout = 1
      http.read_timeout = 1
      req = Net::HTTP::Put.new(token_uri)
      req["X-aws-ec2-metadata-token-ttl-seconds"] = "60"
      token = http.request(req).body

      ip_uri = URI("http://169.254.169.254/latest/meta-data/local-ipv4")
      req = Net::HTTP::Get.new(ip_uri)
      req["X-aws-ec2-metadata-token"] = token
      http.request(req).body.to_s.strip
    rescue StandardError
      nil
    end

    def rails_env
      ENV["RAILS_ENV"].to_s.strip.then { |s| s.empty? ? nil : s }
    end

    def kamal_destination
      ENV["KAMAL_DESTINATION"].to_s.strip.then { |s| s.empty? ? nil : s }
    end

    def looks_like_developer_laptop?(ips)
      # RFC1918 home/office ranges + common macOS
      return true if ips.any? { |ip| ip.start_with?("192.168.", "10.") && !ip.start_with?("10.0.", "172.") }
      # AWS uses 172.31.x in this project; 192.168 is almost never the app server
      ips.any? { |ip| ip.start_with?("192.168.") }
    end
  end
end
