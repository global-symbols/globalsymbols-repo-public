#!/usr/bin/env bash
set -euo pipefail

COMPOSE_PROJECT="${COMPOSE_PROJECT:-gs-s3-setup}"
BACKUP_DIR="${BACKUP_DIR:-tmp/db_backups}"
DB_NAME="${DB_NAME:-gs-repo-dev}"
DB_USER="${DB_USER:-gs-repo-dev}"
DB_PASS="${DB_PASS:-gs-repo-dev}"

BACKUP_FILE="${1:-}"
if [[ -z "$BACKUP_FILE" ]]; then
  if [[ -f "$BACKUP_DIR/LATEST" ]]; then
    BACKUP_FILE="$(cat "$BACKUP_DIR/LATEST")"
  else
    echo "Usage: script/restore_dev_db.sh [path/to/backup.sql]" >&2
    exit 1
  fi
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "Backup file not found: $BACKUP_FILE" >&2
  exit 1
fi

echo "Restoring ${DB_NAME} from ${BACKUP_FILE}..."
echo "Press Ctrl+C within 5 seconds to cancel..."
sleep 5

docker compose -p "$COMPOSE_PROJECT" exec -T db \
  mysql -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" < "$BACKUP_FILE"

echo "Done."