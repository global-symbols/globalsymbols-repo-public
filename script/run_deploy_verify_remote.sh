#!/usr/bin/env bash
# =============================================================================
# From your laptop: rsync suite to the server and run it THERE.
#
# Usage:
#   script/run_deploy_verify_remote.sh pre_prod
#   script/run_deploy_verify_remote.sh prod
#
# SSH hosts (override with DEPLOY_VERIFY_SSH):
#   pre_prod → global-symbols-ec2-test-t4
#   prod     → global-symbols-ec2   (update when m7g is live)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="${1:-pre_prod}"
PROFILE="${PROFILE//-/_}"
[[ "$PROFILE" == "preprod" ]] && PROFILE="pre_prod"
[[ "$PROFILE" == "production" ]] && PROFILE="prod"

if [[ "$PROFILE" == "pre_prod" ]]; then
  SSH_HOST="${DEPLOY_VERIFY_SSH:-global-symbols-ec2-test-t4}"
else
  SSH_HOST="${DEPLOY_VERIFY_SSH:-global-symbols-ec2}"
fi

REMOTE_ROOT="${DEPLOY_VERIFY_REMOTE_ROOT:-/opt/gs-deploy-verify}"

echo "Syncing deploy_verify → ${SSH_HOST}:${REMOTE_ROOT}"
ssh -o BatchMode=yes "$SSH_HOST" "sudo mkdir -p '$REMOTE_ROOT' && sudo chown \$USER:\$USER '$REMOTE_ROOT'"
rsync -az --delete \
  --exclude '.git' \
  "$REPO_ROOT/deploy_verify/" \
  "$SSH_HOST:$REMOTE_ROOT/deploy_verify/"
rsync -az \
  "$REPO_ROOT/script/run_deploy_verify.sh" \
  "$SSH_HOST:$REMOTE_ROOT/run_deploy_verify.sh"
ssh -o BatchMode=yes "$SSH_HOST" "chmod +x '$REMOTE_ROOT/run_deploy_verify.sh'"

echo "Running suite on $SSH_HOST …"
# Forward optional operator env
ssh -o BatchMode=yes "$SSH_HOST" \
  "DEPLOY_VERIFY_USER_EMAIL='${DEPLOY_VERIFY_USER_EMAIL:-}' \
   DEPLOY_VERIFY_USER_PASSWORD='${DEPLOY_VERIFY_USER_PASSWORD:-}' \
   DEPLOY_VERIFY_TIMEOUT='${DEPLOY_VERIFY_TIMEOUT:-}' \
   bash '$REMOTE_ROOT/run_deploy_verify.sh' '$PROFILE'"

echo "Reports on server: $SSH_HOST:/tmp/deploy_verify/"
