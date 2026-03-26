#!/usr/bin/env bash
# LuhaRide Phase 1 dry-run: validates gateway-first cutover prerequisites.
# This script does NOT stop/start processes. Safe to run repeatedly.
#
# Usage:
#   BACKEND_DIR=/var/www/luharide-backend/backend bash scripts/vps-gateway-first-dry-run.sh

set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-}"
if [[ -z "$BACKEND_DIR" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

cd "$BACKEND_DIR"
echo ">>> [dry-run] backend dir: $BACKEND_DIR"

required_files=(
  "gateway/server.js"
  "microservices/authService.js"
  "microservices/coreService.js"
  "microservices/unionService.js"
  "microservices/platformService.js"
  "pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs"
)

echo ">>> [dry-run] checking required files"
for f in "${required_files[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "FAIL missing file: $f"
    exit 1
  fi
done
echo "OK   required files present"

echo ">>> [dry-run] checking commands"
command -v node >/dev/null || { echo "FAIL node not found"; exit 1; }
command -v npm >/dev/null || { echo "FAIL npm not found"; exit 1; }
command -v pm2 >/dev/null || { echo "FAIL pm2 not found"; exit 1; }
command -v curl >/dev/null || { echo "FAIL curl not found"; exit 1; }
echo "OK   node/npm/pm2/curl available"

echo ">>> [dry-run] node version"
node -v

echo ">>> [dry-run] optional install/migrate check (set SKIP_NPM=1 / SKIP_MIGRATE=1 to skip)"
if [[ "${SKIP_NPM:-0}" != "1" ]]; then
  npm install --production
fi
if [[ "${SKIP_MIGRATE:-0}" != "1" ]]; then
  npm run migrate
fi

echo ">>> [dry-run] PM2 process snapshot"
pm2 list || true

echo ">>> [dry-run] health snapshot on expected ports"
for port in 3000 3001 3002 3003 3004; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${port}/health" || echo "000")
  echo "  :${port}/health -> $code"
done

echo ">>> [dry-run] if gateway already up, check upstream view"
gw_code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:3000/api/health/upstreams" || echo "000")
echo "  :3000/api/health/upstreams -> $gw_code"
if [[ "$gw_code" == "200" || "$gw_code" == "503" ]]; then
  curl -s "http://127.0.0.1:3000/api/health/upstreams" || true
  echo ""
fi

echo ">>> [dry-run] done"
echo "Next: run real cutover script when ready:"
echo "  bash scripts/vps-cutover-luharide-microservices.sh"

