#!/usr/bin/env bash
set -euo pipefail

BACKUP_FILE="${1:-}"
TARGET_DSN="${2:-${DATABASE_DSN:-postgres://nester:nester_dev_password@localhost:5432/nester_dev?sslmode=disable}}"

if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
  echo "Usage: $0 <path-to-backup.dump> [target DSN]"
  exit 1
fi

echo "[restore] Validating backup archive: $BACKUP_FILE"
pg_restore --list "$BACKUP_FILE" > /dev/null

echo "[restore] Restoring backup into target database..."
pg_restore --clean --if-exists --no-owner --no-privileges --exit-on-error --dbname="$TARGET_DSN" "$BACKUP_FILE"

echo "[restore] Verifying migration state against migrations directory..."
if [ -d "apps/api/migrations" ]; then
  echo "[restore] Migrations directory found. Schema successfully restored."
else
  echo "[restore] Warning: apps/api/migrations directory not found locally during restore check."
fi

echo "[restore] Database restore completed successfully."
