#!/usr/bin/env bash
set -euo pipefail

DATABASE_DSN="${DATABASE_DSN:-postgres://nester:nester_dev_password@localhost:5432/nester_dev?sslmode=disable}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
FINAL_FILE="$BACKUP_DIR/nester_${TIMESTAMP}.dump"
TMP_FILE="$FINAL_FILE.tmp"

echo "[backup] Starting pg_dump into custom format..."
pg_dump --format=custom --no-owner --no-privileges "$DATABASE_DSN" > "$TMP_FILE"

echo "[backup] Validating backup artifact with pg_restore --list..."
if ! pg_restore --list "$TMP_FILE" > /dev/null; then
  echo "[backup] ERROR: Backup artifact validation failed!"
  rm -f "$TMP_FILE"
  exit 1
fi

echo "[backup] Running secret tripwire scan on backup content..."
if strings "$TMP_FILE" | grep -qiE 'BEGIN (RSA|EC|PRIVATE) KEY|sentry_auth_token'; then
  echo "[backup] ERROR: Tripwire triggered — potential plaintext secret detected in backup dump!"
  rm -f "$TMP_FILE"
    exit 1
  fi

mv "$TMP_FILE" "$FINAL_FILE"
echo "[backup] Successfully created backup: $FINAL_FILE"

echo "[backup] Pruning backups older than ${BACKUP_RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "nester_*.dump" -type f -mtime +"$BACKUP_RETENTION_DAYS" -delete
echo "[backup] Backup and retention prune completed successfully."
