# Database Backup and Restore Runbook

## Overview

This runbook defines the backup strategy, point-in-time recovery (PITR) procedures, and scheduled restore drill protocol for the Nester database (nester#795).

## Automated Backups & Retention

- **Frequency:** Automated logical backups are triggered daily (or on a scheduled cron/CI pipeline).
- **Format:** Custom PostgreSQL dump format (`pg_dump -Fc`) to support parallel restore, selective table/schema restoration, and robust verification.
- **Retention Policy:** Backups are retained for 14 days by default (`BACKUP_RETENTION_DAYS=14`), after which older artifacts are automatically pruned.
- **Recovery Point Objective (RPO):** Maximum 24 hours data loss for logical backups, or minimal data loss when combined with provider-level PITR.
- **Recovery Time Objective (RTO):** Under 30 minutes.

## Restore Runbook

1. **Prerequisites:**
   - Ensure `pg_restore` and `postgresql-client` matching the server version are installed.
   - Obtain the target backup artifact (`.dump`).
2. **Execution:**
   - Run the restore script:
```bash
     make db-restore FILE=./backups/nester_<timestamp>.dump
```
   - Or invoke directly:
   ```bash
     scripts/db-restore.sh ./backups/nester_<timestamp>.dump [target_dsn]
   ```
3. **Verification & Migration Reconciliation:**
   - The restore script automatically checks the integrity of the archive and reconciles the applied migration versions against `apps/api/migrations/`.
   - If restoring an older backup, run migrations afterward (`RUN_MIGRATIONS=true` or `go run ./cmd/migrate up`).
   - Verify health via the API endpoint `/health/detailed` before routing production traffic.

## Restore Drill Protocol & Findings

- **Schedule:** Automated restore drills run on a scheduled cron workflow (`.github/workflows/db-restore-drill.yml`) to ensure backup validity is continuously tested rather than assumed.
- **Drill Flow:**
  1. Selects the most recent backup artifact.
  2. Provisions a scratch database (`nester_restore_drill`).
  3. Restores the dump and performs schema/table integrity assertions.
- **Drill Findings & Runbook Updates:**
  - *Finding 1:* Early scratch restores failed when conflicting active connections locked `nester_dev`. *Resolution:* Isolated scratch database usage to `nester_restore_drill` and added explicit `DROP/CREATE DATABASE` handling in `scripts/db-restore-drill.sh`.
  - *Finding 2:* Silent truncation risk during network interruptions. *Resolution:* Implemented `.tmp` staging rename and `pg_restore --list` validation tripwires in `db-backup.sh`.
