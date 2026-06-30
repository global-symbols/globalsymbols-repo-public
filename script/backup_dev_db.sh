#!/usr/bin/env bash
set -euo pipefail

COMPOSE_PROJECT="${COMPOSE_PROJECT:-gs-s3-setup}"
BACKUP_DIR="${BACKUP_DIR:-tmp/db_backups}"
DB_NAME="${DB_NAME:-gs-repo-dev}"
DB_USER="${DB_USER:-gs-repo-dev}"
DB_PASS="${DB_PASS:-gs-repo-dev}"

mkdir -p "$BACKUP_DIR"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql"

echo "Backing up ${DB_NAME} to ${BACKUP_FILE}..."

docker compose -p "$COMPOSE_PROJECT" exec -T db \
  mysqldump -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$BACKUP_FILE"

echo "$BACKUP_FILE" > "$BACKUP_DIR/LATEST"
echo "Done."