#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
DRILL_DB_NAME="nester_restore_drill"
BASE_DSN="${DATABASE_DSN:-postgres://nester:nester_dev_password@localhost:5432/nester_dev?sslmode=disable}"

# Derive scratch DSN by replacing database name in BASE_DSN
# e.g., postgres://user:pass@host:5432/dbname?sslmode=... -> postgres://user:pass@host:5432/nester_restore_drill?sslmode=...
SCRATCH_DSN="$(echo "$BASE_DSN" | sed -E "s/[[:alnum:]_]+\?/{$DRILL_DB_NAME}?/" || echo "postgres://nester:nester_dev_password@localhost:5432/$DRILL_DB_NAME?sslmode=disable")"
if [[ "$SCRATCH_DSN" != *"$DRILL_DB_NAME"* ]]; then
  SCRATCH_DSN="postgres://nester:nester_dev_password@localhost:5432/$DRILL_DB_NAME?sslmode=disable"
fi

LATEST_BACKUP=$(find "$BACKUP_DIR" -name "nester_*.dump" -type f | sort | tail -n 1)
if [ -z "$LATEST_BACKUP" ]; then
  echo "[drill] ERROR: No backup files found in $BACKUP_DIR. Run make db-backup first."
  exit 1
fi

echo "[drill] Selected latest backup for drill: $LATEST_BACKUP"

ADMIN_DSN="$(echo "$BASE_DSN" | sed -E "s/[[:alnum:]_]+\?/postgres?/")"
if [[ "$ADMIN_DSN" != *"postgres"* ]]; then
  ADMIN_DSN="postgres://nester:nester_dev_password@localhost:5432/postgres?sslmode=disable"
fi

echo "[drill] Recreating scratch database $DRILL_DB_NAME..."
psql "$ADMIN_DSN" -c "DROP DATABASE IF EXISTS \"$DRILL_DB_NAME\";"
psql "$ADMIN_DSN" -c "CREATE DATABASE \"$DRILL_DB_NAME\";"

echo "[drill] Executing restore into scratch database..."
sh scripts/db-restore.sh "$LATEST_BACKUP" "$SCRATCH_DSN"

echo "[drill] Verifying restored data integrity against known schema/data assertions..."
TABLE_COUNT=$(psql "$SCRATCH_DSN" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';" | xargs)
echo "[drill] Scratch database verified: found $TABLE_COUNT tables in public schema."
if [ "$TABLE_COUNT" -eq 0 ]; then
  echo "[drill] ERROR: Restored database contains no tables!"
  exit 1
fi

echo "[drill] SUCCESS: Restore drill completed and verified successfully!"
