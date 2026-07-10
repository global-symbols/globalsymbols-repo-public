#!/usr/bin/env bash
# =============================================================================
# Post-deploy verification — run ON the app server (pre-prod t4g / prod host).
#
# Not intended for your Mac (Redis private IP, real edge path = local proxy).
#
# Usage (SSH to server first, or via the remote helper from your laptop):
#   script/run_deploy_verify.sh pre_prod
#   script/run_deploy_verify.sh prod
#
# Prefer:
#   script/run_deploy_verify_remote.sh pre_prod   # from laptop → SSH → this script on host
#
# Defaults (on-server):
#   DEPLOY_VERIFY_BASE_URL=http://127.0.0.1          # kamal-proxy on host :80
#   DEPLOY_VERIFY_HOST_HEADER=gs-test.co.uk|globalsymbols.com
#   REDIS_IP=172.31.13.8  REDIS_CACHE_DB=2 (pre-prod)
#
# Env is imported from the running web container when present.
# On failure: report + exit 1 (notify-only; no auto-remediation).
# =============================================================================

set -euo pipefail

PROFILE="${1:-pre_prod}"
PROFILE="${PROFILE//-/_}"
[[ "$PROFILE" == "preprod" ]] && PROFILE="pre_prod"
[[ "$PROFILE" == "production" ]] && PROFILE="prod"

echo "Deploy verify on $(hostname) profile=$PROFILE"

# --- Pull env from running Kamal web container (if any) ---
WEB_FILTER="gs-repo-web-pre-prod"
[[ "$PROFILE" == "prod" ]] && WEB_FILTER="gs-repo-web-production"
# destination label may vary; also match generic web
WEB_ID="$(docker ps -q --filter "name=${WEB_FILTER}" | head -1 || true)"
if [[ -z "$WEB_ID" ]]; then
  WEB_ID="$(docker ps -q --filter "label=service=gs-repo" --filter "label=role=web" | head -1 || true)"
fi

if [[ -n "${WEB_ID:-}" ]]; then
  echo "Importing env from web container $WEB_ID"
  # Export selected keys from container into this shell
  while IFS= read -r line; do
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      REDIS_IP|REDIS_PASSWORD|REDIS_DB|REDIS_CACHE_DB|DIRECTUS_URL|DIRECTUS_TOKEN_CMS|DIRECTUS_TOKEN|DIRECTUS_WEBHOOK_SECRET|GS_DATABASE_PASSWORD|SECRET_KEY_BASE|RAILS_ENV|ASSET_HOST)
        # do not override if already set in environment
        if [[ -z "${!key:-}" ]]; then
          export "$key=$val"
        fi
        ;;
    esac
  done < <(docker exec "$WEB_ID" env 2>/dev/null || true)
else
  echo "WARN: no web container found; relying on ambient env / files"
fi

# On-server HTTP defaults (kamal-proxy publishes 80 on the host)
export DEPLOY_VERIFY_BASE_URL="${DEPLOY_VERIFY_BASE_URL:-http://127.0.0.1}"
if [[ "$PROFILE" == "pre_prod" ]]; then
  export DEPLOY_VERIFY_HOST_HEADER="${DEPLOY_VERIFY_HOST_HEADER:-gs-test.co.uk}"
else
  export DEPLOY_VERIFY_HOST_HEADER="${DEPLOY_VERIFY_HOST_HEADER:-globalsymbols.com}"
fi
export DEPLOY_VERIFY_REPORT_DIR="${DEPLOY_VERIFY_REPORT_DIR:-/tmp/deploy_verify}"
export REDIS_IP="${REDIS_IP:-172.31.13.8}"
if [[ "$PROFILE" == "pre_prod" ]]; then
  export REDIS_CACHE_DB="${REDIS_CACHE_DB:-2}"
else
  export REDIS_CACHE_DB="${REDIS_CACHE_DB:-3}"
fi

mkdir -p "$DEPLOY_VERIFY_REPORT_DIR"

# --- Locate suite source ---
# 1) Inside web image (preferred after image includes deploy_verify/)
# 2) /opt/gs-deploy-verify or $HOME/deploy_verify checkout on host
# 3) Same path as this script's repo (if full repo is on server)

run_in_web_container() {
  local id="$1"
  echo "Running suite inside web container $id"
  docker exec \
    -e DEPLOY_VERIFY_BASE_URL \
    -e DEPLOY_VERIFY_HOST_HEADER \
    -e DEPLOY_VERIFY_TIMEOUT \
    -e DEPLOY_VERIFY_REPORT_DIR=/tmp/deploy_verify \
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
    -e REDIS_DB \
    "$id" \
    bash -lc "mkdir -p /tmp/deploy_verify && cd /rails && ruby deploy_verify/runner.rb '$PROFILE'"
  # copy report out if possible
  docker cp "$id:/tmp/deploy_verify/." "$DEPLOY_VERIFY_REPORT_DIR/" 2>/dev/null || true
}

run_with_host_ruby() {
  local root="$1"
  echo "Running suite with host ruby from $root"
  cd "$root"
  exec ruby deploy_verify/runner.rb "$PROFILE"
}

run_with_docker_ruby() {
  local root="$1"
  echo "Running suite via docker ruby (network host) from $root"
  # host network so 127.0.0.1:80 = kamal-proxy and Redis VPC IP is reachable
  docker run --rm --network host \
    -v "$root/deploy_verify":/verify/deploy_verify:ro \
    -w /verify \
    -e DEPLOY_VERIFY_BASE_URL \
    -e DEPLOY_VERIFY_HOST_HEADER \
    -e DEPLOY_VERIFY_TIMEOUT \
    -e DEPLOY_VERIFY_REPORT_DIR=/tmp/deploy_verify \
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
    -e REDIS_DB \
    -v "$DEPLOY_VERIFY_REPORT_DIR":/tmp/deploy_verify \
    ruby:3.2-bookworm \
    ruby deploy_verify/runner.rb "$PROFILE"
}

if [[ -n "${WEB_ID:-}" ]] && docker exec "$WEB_ID" test -f /rails/deploy_verify/runner.rb 2>/dev/null; then
  run_in_web_container "$WEB_ID"
  exit $?
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANDIDATES=(
  "${DEPLOY_VERIFY_ROOT:-}"
  "$HOME/deploy_verify_repo"
  "/opt/gs-deploy-verify"
  "$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"
)

ROOT=""
for c in "${CANDIDATES[@]}"; do
  [[ -z "$c" ]] && continue
  if [[ -f "$c/deploy_verify/runner.rb" ]]; then
    ROOT="$c"
    break
  fi
done

if [[ -z "$ROOT" ]]; then
  echo "ERROR: deploy_verify suite not found on this host."
  echo "  Options:"
  echo "  1) Redeploy an image that includes deploy_verify/ then re-run"
  echo "  2) Clone/copy the repo to /opt/gs-deploy-verify or \$HOME/deploy_verify_repo"
  echo "  3) From laptop: script/run_deploy_verify_remote.sh $PROFILE"
  exit 2
fi

if command -v ruby >/dev/null 2>&1; then
  run_with_host_ruby "$ROOT"
else
  run_with_docker_ruby "$ROOT"
fi
