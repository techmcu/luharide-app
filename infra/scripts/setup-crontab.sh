#!/usr/bin/env bash
# Setup crontab for LuhaRide backup + health monitor
# Usage: bash /var/www/luharide-backend/infra/scripts/setup-crontab.sh

set -euo pipefail

BACKUP_LINE='30 21 * * * /var/www/luharide-backend/infra/scripts/pg-backup.sh >> /var/log/luharide-backup.log 2>&1'
MONITOR_LINE='*/5 * * * * /var/www/luharide-backend/infra/scripts/health-monitor.sh >> /var/log/luharide-monitor.log 2>&1'

EXISTING=$(crontab -l 2>/dev/null || true)

add_if_missing() {
  local line="$1"
  if echo "$EXISTING" | grep -qF "$line"; then
    echo "Already exists: $line"
  else
    EXISTING="${EXISTING}
${line}"
    echo "Added: $line"
  fi
}

add_if_missing "$BACKUP_LINE"
add_if_missing "$MONITOR_LINE"

echo "$EXISTING" | crontab -

echo ""
echo "Current crontab:"
crontab -l
echo ""
echo "Done! Backup: daily 3 AM IST | Monitor: every 5 min"
