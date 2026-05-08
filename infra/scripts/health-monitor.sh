#!/usr/bin/env bash
# =============================================================================
# LuhaRide health monitor — checks services, restarts if down, logs alerts
#
# SETUP (run once on VPS as root):
#   chmod +x /var/www/luharide-backend/infra/scripts/health-monitor.sh
#   # Add to crontab (every 5 minutes):
#   crontab -e
#   */5 * * * * /var/www/luharide-backend/infra/scripts/health-monitor.sh >> /var/log/luharide-monitor.log 2>&1
# =============================================================================

set -uo pipefail

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
GATEWAY_URL="${LUHA_GATEWAY_URL:-http://localhost:3000}"
ALERT_LOG="/var/log/luharide-alerts.log"
ISSUES=0

check_endpoint() {
  local name="$1"
  local url="$2"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")
  if [ "$status" -ge 200 ] && [ "$status" -lt 300 ]; then
    return 0
  else
    echo "[$TIMESTAMP] ALERT: $name returned HTTP $status ($url)" | tee -a "$ALERT_LOG"
    ISSUES=$((ISSUES + 1))
    return 1
  fi
}

check_pm2_service() {
  local name="$1"
  local status
  status=$(pm2 jlist 2>/dev/null | python3 -c "
import sys, json
procs = json.load(sys.stdin)
for p in procs:
    if p['name'] == '$name':
        print(p['pm2_env']['status'])
        break
" 2>/dev/null || echo "unknown")
  if [ "$status" != "online" ]; then
    echo "[$TIMESTAMP] ALERT: PM2 $name is $status — restarting" | tee -a "$ALERT_LOG"
    pm2 restart "$name" 2>/dev/null
    ISSUES=$((ISSUES + 1))
    return 1
  fi
  return 0
}

check_disk() {
  local usage
  usage=$(df / --output=pcent | tail -1 | tr -d ' %')
  if [ "$usage" -gt 90 ]; then
    echo "[$TIMESTAMP] ALERT: Disk usage ${usage}% (>90%)" | tee -a "$ALERT_LOG"
    ISSUES=$((ISSUES + 1))
  fi
}

check_memory() {
  local avail_mb
  avail_mb=$(free -m | awk '/^Mem:/ {print $7}')
  if [ "$avail_mb" -lt 100 ]; then
    echo "[$TIMESTAMP] ALERT: Available memory ${avail_mb}MB (<100MB)" | tee -a "$ALERT_LOG"
    ISSUES=$((ISSUES + 1))
  fi
}

# --- Run checks ---
echo "[$TIMESTAMP] Health check started"

# Gateway health
check_endpoint "gateway" "$GATEWAY_URL/health"

# Upstream services via gateway
check_endpoint "upstreams" "$GATEWAY_URL/health/upstreams"

# Circuit breakers
CIRCUIT_STATUS=$(curl -s --max-time 10 "$GATEWAY_URL/health/circuits" 2>/dev/null)
if echo "$CIRCUIT_STATUS" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('ok') else 1)" 2>/dev/null; then
  :
else
  echo "[$TIMESTAMP] ALERT: Circuit breaker(s) OPEN" | tee -a "$ALERT_LOG"
  ISSUES=$((ISSUES + 1))
fi

# PM2 services
check_pm2_service "luharide-api-gateway"
check_pm2_service "luharide-auth-service"
check_pm2_service "luharide-core-ride-service"
check_pm2_service "luharide-platform-admin-payments-service"
check_pm2_service "luharide-union-admin-service"

# System resources
check_disk
check_memory

# Summary
if [ "$ISSUES" -eq 0 ]; then
  echo "[$TIMESTAMP] All OK"
else
  echo "[$TIMESTAMP] $ISSUES issue(s) detected"
fi
