#!/usr/bin/env bash
# Post-deploy verification suites (black-box HTTP + optional Directus/Redis/CRUD).
#
# Usage:
#   script/run_deploy_verify.sh pre_prod
#   script/run_deploy_verify.sh prod
#
# Environment (common):
#   DEPLOY_VERIFY_BASE_URL      default pre_prod: http://gs-test.co.uk  prod: https://globalsymbols.com
#   DEPLOY_VERIFY_HOST_HEADER   optional Host header when BASE_URL is an IP
#   DEPLOY_VERIFY_TIMEOUT       seconds (default 30)
#   DEPLOY_VERIFY_REPORT_DIR    default tmp/deploy_verify
#
# Pre-prod extras:
#   DEPLOY_VERIFY_USER_EMAIL / DEPLOY_VERIFY_USER_PASSWORD   enable auth+CRUD
#   DIRECTUS_URL or DEPLOY_VERIFY_DIRECTUS_URL
#   DIRECTUS_TOKEN_CMS or DEPLOY_VERIFY_DIRECTUS_TOKEN
#   REDIS_IP / REDIS_PASSWORD / REDIS_CACHE_DB               enable Redis probe (needs network path)
#
# Loads .kamal/secrets-common and .kamal/secrets.pre-prod if present (does not override existing env).
#
# On failure: prints failures + writes markdown report. Exit 1. No auto-remediation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="${1:-pre_prod}"

cd "$REPO_ROOT"

# Prefer project ruby if available; else system ruby
if command -v ruby >/dev/null 2>&1; then
  exec ruby "$REPO_ROOT/deploy_verify/runner.rb" "$PROFILE"
fi

# Fallback: run via docker (stdlib only; no bundle needed)
exec docker run --rm \
  -v "$REPO_ROOT":/rails \
  -w /rails \
  -e DEPLOY_VERIFY_BASE_URL \
  -e DEPLOY_VERIFY_HOST_HEADER \
  -e DEPLOY_VERIFY_TIMEOUT \
  -e DEPLOY_VERIFY_REPORT_DIR \
  -e DEPLOY_VERIFY_USER_EMAIL \
  -e DEPLOY_VERIFY_USER_PASSWORD \
  -e DEPLOY_VERIFY_DIRECTUS_URL \
  -e DEPLOY_VERIFY_DIRECTUS_TOKEN \
  -e DEPLOY_VERIFY_DIRECTUS_RECENT_DAYS \
  -e DEPLOY_VERIFY_REDIS_IP \
  -e DEPLOY_VERIFY_REDIS_PASSWORD \
  -e DEPLOY_VERIFY_REDIS_CACHE_DB \
  -e DEPLOY_VERIFY_PROD_SYMBOLSET_PATH \
  -e DIRECTUS_URL \
  -e DIRECTUS_TOKEN_CMS \
  -e DIRECTUS_TOKEN \
  -e REDIS_IP \
  -e REDIS_PASSWORD \
  -e REDIS_CACHE_DB \
  ruby:3.2-bookworm \
  ruby deploy_verify/runner.rb "$PROFILE"
