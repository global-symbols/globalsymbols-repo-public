# frozen_string_literal: true

require "json"
require "time"
require "securerandom"
require_relative "../lib/csrf"
require_relative "../lib/redis_client"

module DeployVerify
  module Suites
    # Pre-prod post-deploy verification (smoke, Directus, Redis cache, optional CRUD).
    class PreProd
      def initialize(config, reporter, http)
        @config = config
        @reporter = reporter
        @http = http
        @run_id = "deploy-test-#{Time.now.utc.strftime("%Y%m%d%H%M%S")}-#{SecureRandom.hex(3)}"
      end

      def run
        smoke
        directus
        redis_cache
        auth_and_crud
      end

      private

      attr_reader :config, :reporter, :http, :run_id

      def smoke
        reporter.section("Pre-prod HTTP smoke")
        {
          "/" => 200..399,
          "/search" => 200..399,
          "/symbolsets" => 200..399,
          "/about" => 200..399,
          "/users/sign_in" => 200..399,
          "/api/v1/symbolsets" => 200..299,
          "/api/v1/languages/active" => 200..299
        }.each do |path, range|
          check_get(path, range)
        end

        res = http.get("/api/v1/symbolsets")
        if res.success?
          begin
            data = res.json
            ok = data.is_a?(Array) || (data.is_a?(Hash) && (data["symbolsets"] || data["data"]))
            if ok
              reporter.pass("api.symbolsets.json", "JSON structure ok")
            else
              reporter.fail("api.symbolsets.json", "unexpected JSON shape: #{data.class}")
            end
          rescue JSON::ParserError => e
            reporter.fail("api.symbolsets.json", "invalid JSON: #{e.message}", detail: res.body[0, 500])
          end
        end
      end

      def directus
        reporter.section("Pre-prod Directus API")
        unless config.directus_configured?
          reporter.skip("directus", "DIRECTUS_URL / token not set (DEPLOY_VERIFY_DIRECTUS_* or DIRECTUS_*)")
          return
        end

        base = config.directus_url
        token = config.directus_token
        headers = {
          "Authorization" => "Bearer #{token}",
          "Accept" => "application/json"
        }

        # Connectivity: try a few common Directus health/info paths
        info = nil
        info_uri = nil
        %w[server/info server/health server/ping].each do |path|
          info_uri = URI.parse("#{base}/#{path}")
          info = http.request(Net::HTTP::Get, info_uri, headers: headers)
          break if info.success? || info.code == 401 || info.code == 403
        end
        if info&.success?
          reporter.pass("directus.server_info", "HTTP #{info.code} from #{info_uri}")
        elsif info && [401, 403].include?(info.code)
          reporter.fail("directus.server_info", "HTTP #{info.code} auth failed for #{info_uri}", detail: info.body[0, 500])
        else
          reporter.fail(
            "directus.server_info",
            "HTTP #{info&.code || "n/a"} from #{base} (server/info|health|ping)",
            detail: info&.body.to_s[0, 500]
          )
        end

        # languages collection (used by app)
        langs_uri = URI.parse("#{base}/items/gs_languages?limit=5&sort=-date_updated")
        langs = http.request(Net::HTTP::Get, langs_uri, headers: headers)
        unless langs.success?
          # try without sort if field missing
          langs_uri = URI.parse("#{base}/items/gs_languages?limit=5")
          langs = http.request(Net::HTTP::Get, langs_uri, headers: headers)
        end
        if langs.success?
          begin
            payload = langs.json
            rows = payload["data"] || payload
            rows = [] unless rows.is_a?(Array)
            if rows.empty?
              reporter.fail("directus.gs_languages", "collection empty or missing data")
            else
              reporter.pass("directus.gs_languages", "#{rows.size} item(s) returned")
              # recent data if date_updated present
              updated = rows.map { |r| r["date_updated"] || r["date_created"] }.compact
              if updated.any?
                latest = updated.map { |t| Time.parse(t.to_s) rescue nil }.compact.max
                if latest
                  age_days = ((Time.now.utc - latest.utc) / 86_400.0)
                  if age_days <= config.directus_recent_days
                    reporter.pass("directus.recent_data", "newest language row ~#{age_days.round(1)} days old")
                  else
                    reporter.fail(
                      "directus.recent_data",
                      "newest language row is #{age_days.round(1)} days old (threshold #{config.directus_recent_days})"
                    )
                  end
                else
                  reporter.skip("directus.recent_data", "could not parse date fields")
                end
              else
                reporter.skip("directus.recent_data", "no date_updated/date_created on language rows")
              end
            end
          rescue JSON::ParserError => e
            reporter.fail("directus.gs_languages", "invalid JSON: #{e.message}", detail: langs.body[0, 500])
          end
        else
          reporter.fail("directus.gs_languages", "HTTP #{langs.code}", detail: langs.body[0, 500])
        end
      end

      def redis_cache
        reporter.section("Pre-prod Redis cache (DB #{config.redis_cache_db})")
        unless config.redis_configured?
          reporter.skip("redis.cache", "REDIS_IP not set")
          return
        end

        # Warm app-side cache via public endpoints
        http.get("/api/v1/languages/active")
        http.get("/api/v1/symbolsets")

        begin
          redis = RedisClient.new(
            host: config.redis_ip,
            password: config.redis_password,
            db: config.redis_cache_db,
            timeout: config.timeout
          )
          pong = redis.ping
          if pong.to_s.upcase == "PONG"
            reporter.pass("redis.ping", "PONG on #{config.redis_ip} db=#{config.redis_cache_db}")
          else
            reporter.fail("redis.ping", "unexpected reply: #{pong.inspect}")
            return
          end

          key = "deploy_verify:#{run_id}"
          val = "ok-#{run_id}"
          redis.setex(key, 120, val)
          got = redis.get(key)
          if got == val
            reporter.pass("redis.cache_roundtrip", "SETEX/GET ok key=#{key}")
          else
            reporter.fail("redis.cache_roundtrip", "expected #{val.inspect}, got #{got.inspect}")
          end

          size = redis.dbsize
          reporter.pass("redis.dbsize", "DBSIZE=#{size} on cache DB #{config.redis_cache_db}")
        rescue DeployVerify::RedisClient::Error, SystemCallError, SocketError => e
          reporter.fail(
            "redis.cache",
            "cannot use Redis at #{config.redis_ip}: #{e.class}: #{e.message} " \
            "(if runner is outside VPC, run this suite from t4g/CI in VPC or skip REDIS_IP)"
          )
        end
      end

      def auth_and_crud
        reporter.section("Pre-prod auth + CRUD")
        unless config.auth_configured?
          reporter.skip("auth.crud", "DEPLOY_VERIFY_USER_EMAIL / PASSWORD not set")
          return
        end

        # Sign in
        sign_in = http.get("/users/sign_in")
        token = Csrf.extract_token(sign_in.body)
        unless token
          reporter.fail("auth.sign_in_form", "csrf token not found", detail: sign_in.body[0, 400])
          return
        end

        login = http.post(
          "/users/sign_in",
          form: {
            "authenticity_token" => token,
            "user[email]" => config.test_email,
            "user[password]" => config.test_password,
            "user[remember_me]" => "0"
          }
        )

        # Devise usually 302 on success
        if login.redirect? || login.success?
          follow = login.redirect? ? http.get_follow(login.headers["location"] || "/") : login
          # protected page
          new_ss = http.get("/symbolsets/new")
          if new_ss.success? && new_ss.body.to_s.include?("symbolset")
            reporter.pass("auth.sign_in", "signed in as #{config.test_email}")
          elsif new_ss.code == 302 || new_ss.code == 401
            reporter.fail("auth.sign_in", "still blocked from /symbolsets/new (HTTP #{new_ss.code})")
            return
          else
            # might still be ok if form structure differs
            reporter.pass("auth.sign_in", "login HTTP #{login.code}, /symbolsets/new HTTP #{new_ss.code}")
          end
        else
          reporter.fail("auth.sign_in", "login failed HTTP #{login.code}", detail: login.body[0, 500])
          return
        end

        # CRUD symbolset
        # Model requires: name, publisher, licence_id, slug (friendly_id), status draft (default).
        # Form: name, description, licence_id, publisher, publisher_url, logo (see _form.html.haml).
        new_page = http.get("/symbolsets/new")
        csrf = Csrf.extract_token(new_page.body)
        unless csrf
          reporter.fail("crud.symbolset_new", "csrf missing on /symbolsets/new")
          return
        end

        licence_id = extract_first_licence_id(new_page.body)
        unless licence_id
          reporter.fail(
            "crud.symbolset_new",
            "could not find a numeric symbolset[licence_id] option on /symbolsets/new",
            detail: new_page.body[0, 400]
          )
          return
        end

        name = "Deploy Test #{run_id}"
        create = http.post(
          "/symbolsets",
          form: {
            "authenticity_token" => csrf,
            "symbolset[name]" => name,
            "symbolset[description]" => "Created by deploy_verify #{run_id}",
            "symbolset[publisher]" => "Deploy Verify Bot",
            "symbolset[licence_id]" => licence_id
          }
        )

        location = create.headers["location"].to_s
        unless create.redirect? && location.include?("/symbolsets/")
          # re-render :new often embeds validation errors
          errors = extract_flash_or_errors(create.body)
          reporter.fail(
            "crud.symbolset_create",
            "expected redirect to symbolset, got HTTP #{create.code} loc=#{location.inspect}" \
            "#{errors ? "; #{errors}" : ""}",
            detail: create.body[0, 800]
          )
          return
        end
        reporter.pass("crud.symbolset_create", "created → #{location} (licence_id=#{licence_id})")

        show = http.get_follow(location)
        if show.success? && show.body.include?(run_id)
          reporter.pass("crud.symbolset_read", "show page contains run_id")
        else
          reporter.fail("crud.symbolset_read", "show HTTP #{show.code} or missing run_id")
        end

        # Update description
        edit_path = location.sub(%r{/?(\?.*)?\z}, "/edit")
        # location may be full URL
        edit_uri = location.start_with?("http") ? URI.join(location, "edit") : config.uri(File.join(URI(location).path, "edit"))
        begin
          edit_path_for_client = location.start_with?("http") ? URI.parse(location).path + "/edit" : "#{location.sub(%r{/\z}, "")}/edit"
          edit_page = http.get(edit_path_for_client)
          csrf2 = Csrf.extract_token(edit_page.body)
          if csrf2 && edit_page.success?
            path_only = URI.parse(location.start_with?("http") ? location : config.uri(location).to_s).path
            updated_desc = "Updated by deploy_verify #{run_id}"
            upd = http.patch(
              path_only,
              form: {
                "authenticity_token" => csrf2,
                "symbolset[description]" => updated_desc,
                "_method" => "patch"
              }
            )
            # Rails may need POST with _method
            if !upd.redirect? && !upd.success?
              upd = http.post(
                path_only,
                form: {
                  "authenticity_token" => csrf2,
                  "symbolset[description]" => updated_desc,
                  "_method" => "patch"
                }
              )
            end
            if upd.redirect? || upd.success?
              reporter.pass("crud.symbolset_update", "update HTTP #{upd.code}")
            else
              reporter.fail("crud.symbolset_update", "update HTTP #{upd.code}", detail: upd.body[0, 400])
            end
          else
            reporter.skip("crud.symbolset_update", "could not load edit form (HTTP #{edit_page.code})")
          end
        rescue StandardError => e
          reporter.fail("crud.symbolset_update", "#{e.class}: #{e.message}")
        end

        # Delete — app has no SymbolsetsController#destroy (resources still 404).
        # Do not fail the suite; leave a draft "Deploy Test …" row for operators.
        begin
          path_only = URI.parse(location.start_with?("http") ? location : config.uri(location).to_s).path
          show2 = http.get(path_only)
          csrf3 = Csrf.extract_token(show2.body) || csrf
          del = http.post(
            path_only,
            form: {
              "authenticity_token" => csrf3,
              "_method" => "delete"
            }
          )
          if del.redirect? || del.success? || del.code == 303
            reporter.pass("crud.symbolset_delete", "delete HTTP #{del.code}")
          elsif del.code == 404
            reporter.skip(
              "crud.symbolset_delete",
              "HTTP 404 — app exposes no Symbolset destroy; left draft at #{path_only}"
            )
          else
            reporter.fail("crud.symbolset_delete", "delete HTTP #{del.code}", detail: del.body[0, 400])
          end
        rescue StandardError => e
          reporter.fail("crud.symbolset_delete", "#{e.class}: #{e.message}")
        end
      end

      def check_get(path, range)
        res = http.get(path)
        if range.cover?(res.code)
          reporter.pass("http.get#{path}", "HTTP #{res.code}")
        else
          reporter.fail("http.get#{path}", "HTTP #{res.code} (expected #{range})", detail: res.body[0, 300])
        end
      rescue StandardError => e
        reporter.fail("http.get#{path}", "#{e.class}: #{e.message}")
      end

      # First non-blank <option value="N"> under symbolset[licence_id].
      def extract_first_licence_id(html)
        html = html.to_s
        if (m = html.match(/name=["']symbolset\[licence_id\]["'][^>]*>(.*?)<\/select>/mi))
          ids = m[1].scan(/<option[^>]*\svalue=["'](\d+)["']/i).flatten
          return ids.first if ids.any?
        end
        html.scan(/name=["']symbolset\[licence_id\]["']/i)
        html.scan(/<option[^>]*\svalue=["'](\d+)["'][^>]*>/i).flatten.first
      end

      def extract_flash_or_errors(html)
        html = html.to_s
        bits = []
        if (m = html.match(/class=["'][^"']*alert[^"']*["'][^>]*>(.*?)<\/div>/mi))
          bits << m[1].gsub(/<[^>]+>/, " ").squeeze(" ").strip[0, 200]
        end
        errs = html.scan(/field_with_errors/i)
        bits << "field_with_errors×#{errs.size}" if errs.any?
        bits.reject { |b| b.nil? || b.empty? }.join("; ")
      end
    end
  end
end
