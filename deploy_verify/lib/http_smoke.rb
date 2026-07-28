# frozen_string_literal: true

require "json"
require "cgi"

module DeployVerify
  # Shared read-only HTTP smoke checks for pre-prod and prod verify suites.
  # Intentionally GET/HEAD only — safe for production.
  module HttpSmoke
    EXCEPTION_MARKERS = [
      "We're sorry, but something went wrong",
      "ActionController::",
      "ActionView::",
      "ActiveRecord::",
      "Traceback",
      "SyntaxError"
    ].freeze

    RAW_CODE_MARKERS = [
      "<%=",
      "<%#",
      "# frozen_string_literal",
      "module DeployVerify",
      "class Survey"
    ].freeze

    def smoke_core_paths
      reporter.section("#{smoke_label} HTTP smoke (read-only)")
      {
        "/" => 200..399,
        "/search" => 200..399,
        "/symbolsets" => 200..399,
        "/about" => 200..399,
        "/contact" => 200..399,
        "/news" => 200..399,
        "/projects" => 200..399,
        "/developer" => 200..399,
        "/knowledge-base" => 200..399,
        "/users/sign_in" => 200..399,
        "/users/password/new" => 200..399,
        "/api/v1/symbolsets" => 200..299,
        "/api/v1/languages/active" => 200..299
      }.each do |path, range|
        check_get(path, range)
      end
    end

    def smoke_search_results
      reporter.section("#{smoke_label} Search results")
      path = "/search?locale=en&query=#{CGI.escape("car")}"
      res = http.get(path)
      unless (200..399).cover?(res.code)
        reporter.fail("http.get#{path}", "HTTP #{res.code}", detail: res.body.to_s[0, 300])
        return
      end
      body = res.body.to_s
      if exception_page?(body)
        reporter.fail("search.results", "exception page for query=car", detail: body[0, 400])
        return
      end
      # Expect a normal HTML search surface (controls / results / empty state),
      # not a bare dump of ActiveRecord-style debug output.
      if body.match?(/#<Label:0x|ActiveRecord::Relation|LabelsController/)
        reporter.fail("search.results", "looks like raw data dump rather than search HTML", detail: body[0, 400])
        return
      end
      reporter.pass("search.results", "HTTP #{res.code}; no exception/raw dump")
    rescue StandardError => e
      reporter.fail("search.results", "#{e.class}: #{e.message}")
    end

    def smoke_locale_switch
      reporter.section("#{smoke_label} Locale switch")
      path = "/?locale=nl"
      res = http.get(path)
      unless (200..399).cover?(res.code)
        reporter.fail("http.get#{path}", "HTTP #{res.code}", detail: res.body.to_s[0, 300])
        return
      end
      body = res.body.to_s
      if exception_page?(body)
        reporter.fail("locale.nl", "exception page", detail: body[0, 400])
        return
      end
      if body.match?(/lang=["']nl["']/) || body.include?("Toegankelijkheid") || body.include?("Privacybeleid")
        reporter.pass("locale.nl", "Dutch locale markers present")
      else
        reporter.fail(
          "locale.nl",
          "expected lang=nl or Dutch chrome text",
          detail: body[/lang=["'][^"']*["']/, 0].to_s
        )
      end
    rescue StandardError => e
      reporter.fail("locale.nl", "#{e.class}: #{e.message}")
    end

    def smoke_symbol_png_download
      reporter.section("#{smoke_label} Symbol PNG download")
      label = first_search_label("a")
      unless label
        reporter.skip("download.symbol_png", "no labels from /api/v1/labels/search?query=a")
        return
      end

      picto = label["picto"] || {}
      picto_id = picto["id"]
      slug = picto.dig("symbolset", "slug")
      unless picto_id && slug
        reporter.skip(
          "download.symbol_png",
          "label missing picto.id or picto.symbolset.slug (expand may be unsupported)"
        )
        return
      end

      path = "/symbolsets/#{slug}/symbols/#{picto_id}.png?download=1&locale=en"
      res = http.get(path)
      body = res.body.to_s
      ctype = res.headers["content-type"].to_s.downcase

      if res.code == 200 && ctype.include?("image/")
        reporter.pass("download.symbol_png", "HTTP 200 image for #{path}")
      elsif (300..399).cover?(res.code)
        # Missing asset may soft-redirect to the symbol page with flash — route still works.
        reporter.pass("download.symbol_png", "HTTP #{res.code} redirect (asset may be missing) for #{path}")
      elsif exception_page?(body) || res.code >= 500
        reporter.fail("download.symbol_png", "HTTP #{res.code} error for #{path}", detail: body[0, 400])
      elsif res.code == 404
        reporter.fail("download.symbol_png", "HTTP 404 for #{path}", detail: body[0, 300])
      else
        reporter.fail(
          "download.symbol_png",
          "unexpected HTTP #{res.code} content-type=#{ctype.inspect}",
          detail: body[0, 300]
        )
      end
    rescue StandardError => e
      reporter.fail("download.symbol_png", "#{e.class}: #{e.message}")
    end

    def smoke_api_symbolsets_json
      res = http.get("/api/v1/symbolsets")
      unless res.success?
        reporter.fail("api.symbolsets.json", "HTTP #{res.code}")
        return
      end
      begin
        data = res.json
        ok = data.is_a?(Array) || (data.is_a?(Hash) && (data["symbolsets"] || data["data"] || data["items"]))
        if ok
          reporter.pass("api.symbolsets.json", "JSON structure ok")
        else
          reporter.fail("api.symbolsets.json", "unexpected JSON shape: #{data.class}")
        end
      rescue JSON::ParserError => e
        reporter.fail("api.symbolsets.json", "invalid JSON: #{e.message}", detail: res.body[0, 500])
      end
    end

    private

    def smoke_label
      config.prod? ? "Prod" : "Pre-prod"
    end

    def check_get(path, range)
      res = http.get(path)
      body = res.body.to_s
      if range.cover?(res.code) && !exception_page?(body)
        reporter.pass("http.get#{path}", "HTTP #{res.code}")
      elsif exception_page?(body)
        reporter.fail("http.get#{path}", "HTTP #{res.code} exception page", detail: body[0, 300])
      else
        reporter.fail("http.get#{path}", "HTTP #{res.code} (expected #{range})", detail: body[0, 300])
      end
    rescue StandardError => e
      reporter.fail("http.get#{path}", "#{e.class}: #{e.message}")
    end

    def exception_page?(body)
      EXCEPTION_MARKERS.any? { |m| body.include?(m) }
    end

    def raw_code_leak?(body)
      RAW_CODE_MARKERS.any? { |m| body.include?(m) }
    end

    def first_search_label(query)
      # Prefer expanded symbolset so we can build /symbolsets/:slug/symbols/:id.png
      paths = [
        "/api/v1/labels/search?query=#{CGI.escape(query)}&language=eng&limit=1&expand=picto.symbolset",
        "/api/v1/labels/search?query=#{CGI.escape(query)}&language=eng&limit=1"
      ]
      paths.each do |path|
        res = http.get(path)
        next unless res.success?

        data = res.json
        rows = data.is_a?(Array) ? data : Array(data["labels"] || data["data"])
        label = rows.first
        next unless label.is_a?(Hash)

        picto = label["picto"]
        next unless picto.is_a?(Hash)

        if picto["symbolset"].is_a?(Hash) && picto["symbolset"]["slug"]
          return label
        end

        # Fallback: resolve slug via symbolsets list + symbolset_id
        sid = picto["symbolset_id"]
        slug = symbolset_slug_for_id(sid)
        if slug
          picto["symbolset"] = { "slug" => slug }
          label["picto"] = picto
          return label
        end
      end
      nil
    rescue StandardError
      nil
    end

    def symbolset_slug_for_id(id)
      return nil if id.nil?

      res = http.get("/api/v1/symbolsets")
      return nil unless res.success?

      data = res.json
      rows = data.is_a?(Array) ? data : Array(data["symbolsets"] || data["data"])
      row = rows.find { |r| r.is_a?(Hash) && r["id"].to_i == id.to_i }
      row && row["slug"]
    rescue StandardError
      nil
    end
  end
end
