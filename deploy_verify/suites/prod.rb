# frozen_string_literal: true

require "json"
require_relative "../lib/http_smoke"

module DeployVerify
  module Suites
    # Production post-deploy verification — read-only (GET/HEAD only).
    class Prod
      include DeployVerify::HttpSmoke

      def initialize(config, reporter, http)
        @config = config
        @reporter = reporter
        @http = http
      end

      def run
        enforce_readonly_guards!
        smoke_core_paths
        smoke_api_symbolsets_json
        smoke_search_results
        smoke_locale_switch
        smoke_symbol_png_download
        smoke_head_home
        contracts
        optional_directus_readonly
      end

      private

      attr_reader :config, :reporter, :http

      def enforce_readonly_guards!
        reporter.section("Prod safety guards")
        if config.allow_writes?
          reporter.fail("prod.guard.allow_writes", "prod profile must not allow writes")
        else
          reporter.pass("prod.guard.allow_writes", "writes disabled")
        end

        # Refuse obviously wrong base URL for prod profile
        host = URI.parse(config.base_url).host.to_s
        if host.include?("gs-test") || host.include?("localhost") || host.include?("127.0.0.1")
          reporter.fail("prod.guard.base_url", "refusing prod suite against non-prod host #{host.inspect}")
        else
          reporter.pass("prod.guard.base_url", "base host=#{host}")
        end
      end

      def smoke_head_home
        begin
          res = http.head("/")
          if (200..399).cover?(res.code)
            reporter.pass("http.head/", "HTTP #{res.code}")
          else
            reporter.fail("http.head/", "HTTP #{res.code}")
          end
        rescue StandardError => e
          reporter.fail("http.head/", "#{e.class}: #{e.message}")
        end

        check_get(config.prod_symbolset_path, 200..399)
      end

      def contracts
        reporter.section("Prod API contracts")
        res = http.get("/api/v1/symbolsets")
        unless res.success?
          reporter.fail("contract.symbolsets", "HTTP #{res.code}")
          return
        end
        begin
          data = res.json
          ok = data.is_a?(Array) || (data.is_a?(Hash) && (data.key?("symbolsets") || data.key?("data") || data.key?("items")))
          if ok
            reporter.pass("contract.symbolsets.json", "parseable list-like JSON")
          else
            reporter.fail("contract.symbolsets.json", "unexpected shape #{data.class}")
          end
        rescue JSON::ParserError => e
          reporter.fail("contract.symbolsets.json", e.message, detail: res.body[0, 400])
        end

        res2 = http.get("/api/v1/languages/active")
        if res2.success?
          begin
            data = res2.json
            reporter.pass("contract.languages.json", "HTTP #{res2.code} #{data.class}")
          rescue JSON::ParserError => e
            reporter.fail("contract.languages.json", e.message)
          end
        else
          reporter.fail("contract.languages", "HTTP #{res2.code}")
        end
      end

      def optional_directus_readonly
        reporter.section("Prod Directus (optional read-only)")
        unless config.directus_configured?
          reporter.skip("directus", "not configured")
          return
        end

        base = config.directus_url
        headers = {
          "Authorization" => "Bearer #{config.directus_token}",
          "Accept" => "application/json"
        }
        uri = URI.join("#{base}/", "server/info")
        res = http.request(Net::HTTP::Get, uri, headers: headers)
        if res.success?
          reporter.pass("directus.server_info", "HTTP #{res.code}")
        else
          reporter.fail("directus.server_info", "HTTP #{res.code}", detail: res.body[0, 400])
        end
      end
    end
  end
end
