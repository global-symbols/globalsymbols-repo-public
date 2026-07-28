# frozen_string_literal: true

require "fileutils"
require "time"
require "json"

module DeployVerify
  # Collects results and writes a human-readable report.
  # Notify-only: never triggers deploy/rollback; exit code reflects failures for humans/CI visibility.
  class Reporter
    Result = Struct.new(:name, :status, :message, :detail, keyword_init: true)

    def initialize(config)
      @config = config
      @results = []
      @started_at = Time.now.utc
    end

    def pass(name, message = "ok", detail: nil)
      @results << Result.new(name: name, status: :pass, message: message, detail: detail)
      puts "  PASS  #{name}: #{message}"
    end

    def fail(name, message, detail: nil)
      @results << Result.new(name: name, status: :fail, message: message, detail: detail)
      puts "  FAIL  #{name}: #{message}"
    end

    def skip(name, message)
      @results << Result.new(name: name, status: :skip, message: message, detail: nil)
      puts "  SKIP  #{name}: #{message}"
    end

    def section(title)
      puts "\n== #{title} =="
    end

    def failures
      @results.select { |r| r.status == :fail }
    end

    def passed?
      failures.empty?
    end

    def summary_counts
      {
        pass: @results.count { |r| r.status == :pass },
        fail: @results.count { |r| r.status == :fail },
        skip: @results.count { |r| r.status == :skip }
      }
    end

    def finish!
      ended = Time.now.utc
      counts = summary_counts
      FileUtils.mkdir_p(@config.report_dir)
      stamp = @started_at.strftime("%Y%m%d_%H%M%S")
      path = File.join(@config.report_dir, "deploy_verify_#{@config.profile}_#{stamp}.md")

      File.write(path, render_markdown(ended, counts, path))
      puts "\n" + ("=" * 60)
      puts "Deploy verify [#{@config.profile}] finished"
      puts "  base_url: #{@config.base_url}"
      puts "  pass=#{counts[:pass]} fail=#{counts[:fail]} skip=#{counts[:skip]}"
      puts "  report: #{path}"
      if failures.any?
        puts "\n  NOTIFICATION (action required by human — no auto-remediation):"
        failures.each { |f| puts "    - #{f.name}: #{f.message}" }
      else
        puts "  All executed checks passed (skips are informational)."
      end
      puts ("=" * 60)
      path
    end

    private

    def render_markdown(ended, counts, path)
      lines = []
      lines << "# Deploy verify report — #{@config.profile}"
      lines << ""
      lines << "- Started: #{@started_at.iso8601}"
      lines << "- Ended:   #{ended.iso8601}"
      lines << "- Base URL: #{@config.base_url}"
      lines << "- Host header: #{@config.host_header || "(none)"}"
      lines << "- Result: **#{passed? ? "PASS" : "FAIL"}** (notify-only; human decides next action)"
      lines << "- Counts: pass=#{counts[:pass]} fail=#{counts[:fail]} skip=#{counts[:skip]}"
      lines << ""
      lines << "## Checks"
      lines << ""
      lines << "| Status | Check | Message |"
      lines << "|--------|-------|---------|"
      @results.each do |r|
        msg = r.message.to_s.gsub("|", "\\|").gsub("\n", " ")
        lines << "| #{r.status.upcase} | #{r.name} | #{msg} |"
      end
      if failures.any?
        lines << ""
        lines << "## Failures (detail)"
        lines << ""
        failures.each do |f|
          lines << "### #{f.name}"
          lines << ""
          lines << f.message
          lines << ""
          lines << "```" if f.detail
          lines << f.detail.to_s[0, 4000] if f.detail
          lines << "```" if f.detail
          lines << ""
        end
      end
      lines << ""
      lines << "_Report path: #{path}_"
      lines.join("\n")
    end
  end
end
