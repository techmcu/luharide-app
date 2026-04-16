#!/usr/bin/env bash
# LuhaRide website split:
# - luharide.cloud (+ www): marketing/static homepage
# - luharide.cloud/app: Flutter Web app (same UI as APK)
#
# Run on VPS after git pull:
#   chmod +x infra/scripts/setup-root-website-nginx.sh
#   sudo ./infra/scripts/setup-root-website-nginx.sh
#
# Flutter upload:
#   scp -r webapp/* root@VPS:/var/www/luharide-web/
#   OR scp -r mobile/build/web/* root@VPS:/var/www/luharide-web/
#   then run this script again.
#
# Backend .env (same VPS): CORS_ALLOWED_ORIGINS must include
#   https://luharide.cloud,https://www.luharide.cloud
# so Flutter Web + REST + Socket.IO work (see backend/.env.example).
#
# api.luharide.cloud is unchanged (separate nginx — use WebSocket Upgrade headers; see
# infra/nginx-reverse-proxy-luharide-api-gateway.example.conf).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC="$REPO_ROOT/infra/static-site-luharide-root/index.html"
TARGET_STATIC="/var/www/luharide-cloud"
WEB_FLUTTER="/var/www/luharide-web"
SITE="/etc/nginx/sites-available/luharide-website"

if ! command -v nginx >/dev/null 2>&1; then
  echo "Install nginx first: sudo apt install -y nginx"
  exit 1
fi

if [[ ! -f "$SRC" ]]; then
  echo "Missing: $SRC (run from repo clone on VPS after git pull)"
  exit 1
fi

sudo mkdir -p "$TARGET_STATIC"
sudo cp "$SRC" "$TARGET_STATIC/index.html"
sudo chown -R www-data:www-data "$TARGET_STATIC" 2>/dev/null || true
sudo mkdir -p "$WEB_FLUTTER"
sudo chown -R www-data:www-data "$WEB_FLUTTER" 2>/dev/null || true

sudo tee "$SITE" >/dev/null <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name luharide.cloud www.luharide.cloud;

    root $TARGET_STATIC;
    index index.html;

    # Serve Flutter web app under /app
    location /app/ {
        alias $WEB_FLUTTER/;
        try_files \$uri \$uri/ /app/index.html;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINX

sudo ln -sf "$SITE" /etc/nginx/sites-enabled/luharide-website
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "OK — luharide.cloud → static marketing site ($TARGET_STATIC)"
if [[ -f "$WEB_FLUTTER/index.html" ]]; then
  echo "OK — luharide.cloud/app → Flutter Web app ($WEB_FLUTTER)"
else
  echo "NOTICE — Flutter Web build missing at $WEB_FLUTTER/index.html"
  echo "         Upload webapp/build output to $WEB_FLUTTER for /app route."
fi
echo "HTTPS: sudo certbot --nginx -d luharide.cloud -d www.luharide.cloud"
echo ""
