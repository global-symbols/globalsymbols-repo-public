#!/usr/bin/env ruby
# frozen_string_literal: true

# Deploy verification — runs ON the app server / inside the web container.
# Ships with the app image under /rails/deploy_verify/.
#
#   ruby deploy_verify/runner.rb pre_prod
#   ruby deploy_verify/runner.rb prod
#   /rails/deploy_verify/bin/run pre_prod
#
# Refuses wrong hosts (see lib/runtime_guard.rb).
# On failure: report + exit 1 (notify-only; no auto-remediation).

require "json"
require "net/http"
require "uri"
require "socket"

ROOT = File.expand_path("..", __dir__)
# Support both repo layout (ROOT=repo) and container (/rails)
VERIFY_ROOT = File.expand_path(__dir__)
$LOAD_PATH.unshift(VERIFY_ROOT)

require_relative "lib/config"
require_relative "lib/http_client"
require_relative "lib/reporter"
require_relative "lib/runtime_guard"
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
    ENV[key] = val if ENV[key].to_s.empty? && !key.empty?
  end
end

def load_env_files!(profile)
  # Only load host secret files if present on server (optional).
  # Prefer env already injected into the web container by Kamal.
  load_env_file!(File.join(ROOT, ".kamal", "secrets-common"))
  if profile == "pre_prod"
    load_env_file!(File.join(ROOT, ".kamal", "secrets.pre-prod"))
  else
    load_env_file!(File.join(ROOT, ".kamal", "secrets.production"))
  end
  load_env_file!(File.join(VERIFY_ROOT, ".env"))
end

profile = ARGV[0].to_s.strip
profile = "pre_prod" if profile.empty?
profile = "pre_prod" if profile == "pre-prod"
profile = "prod" if profile == "production"

unless %w[pre_prod prod].include?(profile)
  warn "Usage: ruby deploy_verify/runner.rb [pre_prod|prod]"
  exit 2
end

begin
  DeployVerify::RuntimeGuard.assert!(profile)
rescue DeployVerify::RuntimeGuard::WrongEnvironment => e
  warn e.message
  exit 3
end

load_env_files!(profile)

config = DeployVerify::Config.new(profile)
reporter = DeployVerify::Reporter.new(config)
http = DeployVerify::HttpClient.new(config)

puts "Deploy verify starting (server-only)"
puts "  hostname: #{(Socket.gethostname rescue "unknown")}"
puts "  profile:  #{config.profile}"
puts "  base_url: #{config.base_url}"
puts "  host_hdr: #{config.host_header.inspect}"
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
exit(reporter.passed? ? 0 : 1)
