#!/usr/bin/env bash
# LuhaRide main site — ONE script for luharide.cloud + www
#
# • If /var/www/luharide-web/index.html exists → serve Flutter Web (same UI as APK).
# • Otherwise → copy static landing from repo → /var/www/luharide-cloud (pehle jaisa:
#   marketing page + real login/signup via API fetch).
#
# Run on VPS after git pull:
#   chmod +x infra/scripts/setup-root-website-nginx.sh
#   sudo ./infra/scripts/setup-root-website-nginx.sh
#
# Flutter optional: scp -r mobile/build/web/* root@VPS:/var/www/luharide-web/
# then run this script again — it will switch to Flutter automatically.
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

if [[ -f "$WEB_FLUTTER/index.html" ]]; then
  DOCROOT="$WEB_FLUTTER"
  MODE="flutter"
  sudo chown -R www-data:www-data "$WEB_FLUTTER" 2>/dev/null || true
else
  if [[ ! -f "$SRC" ]]; then
    echo "Missing: $SRC (run from repo clone on VPS after git pull)"
    exit 1
  fi
  DOCROOT="$TARGET_STATIC"
  MODE="static"
  sudo mkdir -p "$TARGET_STATIC"
  sudo cp "$SRC" "$TARGET_STATIC/index.html"
  sudo chown -R www-data:www-data "$TARGET_STATIC" 2>/dev/null || true
fi

sudo tee "$SITE" >/dev/null <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name luharide.cloud www.luharide.cloud;

    root $DOCROOT;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINX

sudo ln -sf "$SITE" /etc/nginx/sites-enabled/luharide-website
sudo nginx -t
sudo systemctl reload nginx

echo ""
if [[ "$MODE" == "flutter" ]]; then
  echo "OK — luharide.cloud → Flutter Web ($DOCROOT)"
else
  echo "OK — luharide.cloud → static landing + API login ($DOCROOT)"
  echo "     For full app UI in browser: upload build/web to $WEB_FLUTTER and re-run this script."
fi
echo "HTTPS: sudo certbot --nginx -d luharide.cloud -d www.luharide.cloud"
echo ""
