#!/usr/bin/env bash
# =============================================================================
# PostgreSQL daily backup for LuhaRide
#
# SETUP (run once on VPS as root):
#   chmod +x /var/www/luharide-backend/infra/scripts/pg-backup.sh
#   mkdir -p /var/backups/luharide
#   # Add to crontab (daily 3 AM IST = 21:30 UTC):
#   crontab -e
#   30 21 * * * /var/www/luharide-backend/infra/scripts/pg-backup.sh >> /var/log/luharide-backup.log 2>&1
#
# RESTORE:
#   gunzip -k /var/backups/luharide/luharide_2026-05-08.sql.gz
#   psql -U postgres -d luharide < /var/backups/luharide/luharide_2026-05-08.sql
# =============================================================================

set -euo pipefail

DB_NAME="${LUHA_DB_NAME:-luharide}"
DB_USER="${LUHA_DB_USER:-postgres}"
BACKUP_DIR="${LUHA_BACKUP_DIR:-/var/backups/luharide}"
KEEP_DAYS="${LUHA_BACKUP_KEEP_DAYS:-14}"

DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[$TIMESTAMP] Starting backup: $DB_NAME → $BACKUP_FILE"

if pg_dump -U "$DB_USER" "$DB_NAME" --no-owner --no-privileges | gzip > "$BACKUP_FILE"; then
  SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
  echo "[$TIMESTAMP] Backup OK: $BACKUP_FILE ($SIZE)"
else
  echo "[$TIMESTAMP] ERROR: pg_dump failed for $DB_NAME"
  exit 1
fi

# Prune old backups
DELETED=$(find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +"$KEEP_DAYS" -delete -print | wc -l)
if [ "$DELETED" -gt 0 ]; then
  echo "[$TIMESTAMP] Pruned $DELETED backups older than $KEEP_DAYS days"
fi

echo "[$TIMESTAMP] Backup complete"
