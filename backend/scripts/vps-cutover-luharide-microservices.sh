#!/usr/bin/env bash
# LuhaRide Phase 2 — VPS: stop monolith PM2 app, start gateway + 4 microservices.
# Run from repo root OR set BACKEND_DIR. Example:
#   BACKEND_DIR=/var/www/luharide-backend/backend bash backend/scripts/vps-cutover-luharide-microservices.sh

set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-}"
if [[ -z "$BACKEND_DIR" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

cd "$BACKEND_DIR"
echo ">>> backend dir: $BACKEND_DIR"

if [[ ! -f "pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs" ]]; then
  echo "ERROR: ecosystem file missing. Run from LuhaRide backend/ or set BACKEND_DIR."
  exit 1
fi

echo ">>> git pull (skip with SKIP_GIT_PULL=1)"
if [[ "${SKIP_GIT_PULL:-0}" != "1" ]]; then
  git pull
fi

echo ">>> npm install"
npm install --production

echo ">>> migrate"
npm run migrate

echo ">>> stop/delete old monolith (luharide-api)"
pm2 stop luharide-api 2>/dev/null || true
pm2 delete luharide-api 2>/dev/null || true

echo ">>> start microservices + gateway"
pm2 start pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs

echo ">>> pm2 save"
pm2 save

echo ">>> health checks (expect 200)"
for port in 3000 3001 3002 3003 3004; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${port}/health" || echo "000")
  echo "  :${port}/health -> $code"
done

echo ">>> done. Run: pm2 list"
pm2 list
