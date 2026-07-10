#!/usr/bin/env bash
# =============================================================================
# Run deploy verify ON THIS app server only (pre-prod t4g or prod host).
#
# Preferred (ships with the app image):
#   WEB=$(docker ps -q -f name=gs-repo-web-pre-prod | head -1)
#   docker exec "$WEB" /rails/deploy_verify/bin/run pre_prod
#
# This host script:
#   - finds the web container
#   - execs the suite inside it (suite is part of the image)
#   - refuses to run if not on an allowed host IP
#
# There is intentionally NO laptop remote runner.
# =============================================================================
set -euo pipefail

PROFILE="${1:-}"
if [[ -z "$PROFILE" ]]; then
  echo "Usage: $0 <pre_prod|prod>"
  exit 2
fi
PROFILE="${PROFILE//-/_}"
[[ "$PROFILE" == "preprod" ]] && PROFILE="pre_prod"
[[ "$PROFILE" == "production" ]] && PROFILE="prod"

# --- Host allowlist (must match deploy_verify/lib/runtime_guard.rb) ---
ALLOWED_PRE_PROD_IPS=(172.31.30.149)
ALLOWED_PROD_IPS=(172.31.6.238)

private_ips() {
  hostname -I 2>/dev/null || true
  # EC2 IMDSv2 best-effort
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --max-time 1 2>/dev/null || true)
  if [[ -n "$TOKEN" ]]; then
    curl -s -H "X-aws-ec2-metadata-token: $TOKEN" --max-time 1 \
      http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || true
  fi
}

IPS="$(private_ips | tr ' ' '\n' | sort -u)"
allowed=()
if [[ "$PROFILE" == "pre_prod" ]]; then
  allowed=("${ALLOWED_PRE_PROD_IPS[@]}")
else
  allowed=("${ALLOWED_PROD_IPS[@]}")
fi

ok=0
for a in "${allowed[@]}"; do
  if echo "$IPS" | grep -qx "$a"; then ok=1; break; fi
done
if [[ -n "${DEPLOY_VERIFY_ALLOWED_IPS:-}" ]]; then
  ok=0
  for a in ${DEPLOY_VERIFY_ALLOWED_IPS//,/ }; do
    if echo "$IPS" | grep -qx "$a"; then ok=1; break; fi
  done
fi

if [[ "$ok" -ne 1 ]]; then
  echo "ERROR: refusing deploy verify [$PROFILE] on this host."
  echo "  host IPs: $(echo $IPS | tr '\n' ' ')"
  echo "  allowlist: ${allowed[*]}"
  echo "  Run only on the ${PROFILE} app server, inside its environment."
  exit 3
fi

WEB_FILTER="gs-repo-web-pre-prod"
[[ "$PROFILE" == "prod" ]] && WEB_FILTER="gs-repo-web-production"
WEB_ID="$(docker ps -q --filter "name=${WEB_FILTER}" | head -1 || true)"
if [[ -z "${WEB_ID:-}" ]]; then
  WEB_ID="$(docker ps -q --filter "label=service=gs-repo" --filter "label=role=web" | head -1 || true)"
fi

if [[ -z "${WEB_ID:-}" ]]; then
  echo "ERROR: no gs-repo web container running on this host."
  exit 2
fi

if ! docker exec "$WEB_ID" test -f /rails/deploy_verify/runner.rb; then
  echo "ERROR: deploy_verify not found in image (container $WEB_ID)."
  echo "  Redeploy an image built after deploy_verify was added to the repo."
  exit 2
fi

echo "Running deploy_verify [$PROFILE] inside container $WEB_ID on $(hostname)"

# On-server HTTP defaults (loopback proxy from *host* network is not visible inside
# container — use kamal-proxy service name on the kamal network)
export DEPLOY_VERIFY_BASE_URL="${DEPLOY_VERIFY_BASE_URL:-http://kamal-proxy}"
if [[ "$PROFILE" == "pre_prod" ]]; then
  export DEPLOY_VERIFY_HOST_HEADER="${DEPLOY_VERIFY_HOST_HEADER:-gs-test.co.uk}"
else
  export DEPLOY_VERIFY_HOST_HEADER="${DEPLOY_VERIFY_HOST_HEADER:-globalsymbols.com}"
fi

set +e
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
  -e DEPLOY_VERIFY_ALLOWED_IPS \
  "$WEB_ID" \
  bash -lc "mkdir -p /tmp/deploy_verify && /rails/deploy_verify/bin/run '$PROFILE'"
RC=$?
set -e

# Copy reports to host /tmp for operators
mkdir -p /tmp/deploy_verify
docker cp "$WEB_ID:/tmp/deploy_verify/." /tmp/deploy_verify/ 2>/dev/null || true
echo "Reports (host): /tmp/deploy_verify/  (also in container /tmp/deploy_verify/)"
exit "$RC"
