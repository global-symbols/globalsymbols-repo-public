# frozen_string_literal: true

require "uri"

module DeployVerify
  # Environment configuration for deploy verification suites.
  #
  # Intended to run ON the app server (pre-prod t4g / prod m7g), not from a laptop.
  # Defaults hit local kamal-proxy (127.0.0.1) with the public Host header.
  class Config
    attr_reader :profile, :base_url, :host_header

    def initialize(profile)
      @profile = profile.to_s
      raise ArgumentError, "profile must be pre_prod or prod" unless %w[pre_prod prod].include?(@profile)

      # On-server defaults: talk to kamal-proxy on loopback with the real vhost Host header.
      default_base =
        if pre_prod?
          "http://127.0.0.1"
        else
          "http://127.0.0.1"
        end
      default_host =
        if pre_prod?
          "gs-test.co.uk"
        else
          "globalsymbols.com"
        end

      @base_url = required_or_default("DEPLOY_VERIFY_BASE_URL", default_base).sub(%r{/\z}, "")
      @host_header = ENV.key?("DEPLOY_VERIFY_HOST_HEADER") ? ENV["DEPLOY_VERIFY_HOST_HEADER"] : default_host
      @host_header = nil if @host_header.to_s.strip.empty?
    end

    def pre_prod?
      profile == "pre_prod"
    end

    def prod?
      profile == "prod"
    end

    def allow_writes?
      pre_prod?
    end

    def timeout
      (ENV["DEPLOY_VERIFY_TIMEOUT"] || "30").to_i
    end

    def report_dir
      ENV["DEPLOY_VERIFY_REPORT_DIR"] ||
        if File.writable?("/tmp")
          "/tmp/deploy_verify"
        else
          File.expand_path("../../tmp/deploy_verify", __dir__)
        end
    end

    # Optional auth for CRUD / signed-in checks (pre-prod)
    def test_email
      ENV["DEPLOY_VERIFY_USER_EMAIL"]
    end

    def test_password
      ENV["DEPLOY_VERIFY_USER_PASSWORD"]
    end

    def auth_configured?
      test_email.to_s.strip != "" && test_password.to_s.strip != ""
    end

    # Directus
    def directus_url
      raw = ENV["DEPLOY_VERIFY_DIRECTUS_URL"] || ENV["DIRECTUS_URL"]
      raw = "https://cms.gs-test.co.uk" if raw.to_s.strip.empty? && pre_prod?
      raw = "https://cms.globalsymbols.com" if raw.to_s.strip.empty? && prod?
      raw.to_s.sub(%r{/\z}, "")
    end

    def directus_token
      ENV["DEPLOY_VERIFY_DIRECTUS_TOKEN"] || ENV["DIRECTUS_TOKEN_CMS"] || ENV["DIRECTUS_TOKEN"]
    end

    def directus_configured?
      directus_url != "" && directus_token.to_s.strip != ""
    end

    def directus_recent_days
      (ENV["DEPLOY_VERIFY_DIRECTUS_RECENT_DAYS"] || "90").to_i
    end

    # Redis cache — on-server defaults match topology (reachable from t4g/m7g)
    def redis_ip
      raw = ENV["DEPLOY_VERIFY_REDIS_IP"] || ENV["REDIS_IP"]
      raw = "172.31.13.8" if raw.to_s.strip.empty? && pre_prod?
      raw
    end

    def redis_password
      ENV["DEPLOY_VERIFY_REDIS_PASSWORD"] || ENV["REDIS_PASSWORD"]
    end

    def redis_cache_db
      default_db = pre_prod? ? "2" : "3"
      (ENV["DEPLOY_VERIFY_REDIS_CACHE_DB"] || ENV["REDIS_CACHE_DB"] || default_db).to_i
    end

    def redis_configured?
      return false if prod?
      redis_ip.to_s.strip != ""
    end

    def prod_symbolset_path
      ENV["DEPLOY_VERIFY_PROD_SYMBOLSET_PATH"] || "/symbolsets"
    end

    def notify?
      true
    end

    def uri(path = "/")
      path = "/#{path}" unless path.start_with?("/")
      URI.join("#{base_url}/", path.sub(%r{\A/}, ""))
    end

    private

    def required_or_default(key, default)
      val = ENV[key].to_s.strip
      val.empty? ? default : val
    end
  end
end
