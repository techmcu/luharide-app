#!/usr/bin/env bash
# Same as build_web_production.ps1 — run from repo: mobile/
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release \
  --dart-define=API_BASE_URL=https://luharide.cloud/api \
  --dart-define=SOCKET_URL=https://luharide.cloud \
  --dart-define=STABLE_RELEASE=true
echo ""
echo "Output: $(pwd)/build/web"
echo "Deploy: scp -r build/web/* user@VPS:/var/www/luharide-web/"
echo "VPS:    sudo bash infra/scripts/setup-root-website-nginx.sh"
