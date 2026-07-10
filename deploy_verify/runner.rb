#!/usr/bin/env ruby
# frozen_string_literal: true

# Deploy verification entrypoint (stdlib + suite files only).
#
#   ruby deploy_verify/runner.rb pre_prod
#   ruby deploy_verify/runner.rb prod
#
# Or via scripts:
#   script/run_deploy_verify.sh pre_prod
#   script/run_deploy_verify.sh prod
#
# Failure policy: print + write report (notification). Exit 1 if any check failed
# so humans/CI can see it; no auto-remediation.

require "json"
require "net/http"
require "uri"

ROOT = File.expand_path("..", __dir__)
$LOAD_PATH.unshift(File.join(ROOT, "deploy_verify"))

require_relative "lib/config"
require_relative "lib/http_client"
require_relative "lib/reporter"
require_relative "suites/pre_prod"
require_relative "suites/prod"

def load_env_file!(path)
  return unless File.file?(path)

  File.foreach(path) do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")
    next unless line.include?("=")

    key, val = line.split("=", 2)
    key = key.strip
    val = val.strip
    # do not override already-exported env
    ENV[key] = val if ENV[key].to_s.empty? && !key.empty?
  end
end

def load_env_files!(profile)
  # Optional: load .kamal secrets if present (local operator convenience)
  load_env_file!(File.join(ROOT, ".kamal", "secrets-common"))
  if profile == "pre_prod"
    load_env_file!(File.join(ROOT, ".kamal", "secrets.pre-prod"))
  else
    load_env_file!(File.join(ROOT, ".kamal", "secrets.production"))
  end
  load_env_file!(File.join(ROOT, "deploy_verify", ".env"))
  load_env_file!(File.join(ROOT, "deploy_verify", ".env.local"))
end

profile = ARGV[0].to_s.strip
profile = "pre_prod" if profile.empty?
profile = "pre_prod" if profile == "pre-prod"
profile = "prod" if profile == "production"

unless %w[pre_prod prod].include?(profile)
  warn "Usage: ruby deploy_verify/runner.rb [pre_prod|prod]"
  exit 2
end

load_env_files!(profile)

config = DeployVerify::Config.new(profile)
reporter = DeployVerify::Reporter.new(config)
http = DeployVerify::HttpClient.new(config)

puts "Deploy verify starting"
puts "  profile:  #{config.profile}"
puts "  base_url: #{config.base_url}"
puts "  writes:   #{config.allow_writes?}"
puts "  notify-only on fail (no auto rollback/DNS)"

begin
  suite =
    if config.pre_prod?
      DeployVerify::Suites::PreProd.new(config, reporter, http)
    else
      DeployVerify::Suites::Prod.new(config, reporter, http)
    end
  suite.run
rescue StandardError => e
  reporter.fail("suite.error", "#{e.class}: #{e.message}", detail: e.backtrace&.first(15)&.join("\n"))
end

reporter.finish!

# Exit 1 on failures so operators notice; still "notify-only" (no automated fix).
exit(reporter.passed? ? 0 : 1)
