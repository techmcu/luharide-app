#!/usr/bin/env bash
# VPS: serve Flutter Web (same UI as mobile app) at luharide.cloud
#
# 1) On your PC:  cd mobile && flutter build web --release (see mobile/scripts/build_web_production.ps1)
# 2) Upload:      scp -r mobile/build/web/* root@VPS:/var/www/luharide-web/
# 3) On VPS:      sudo bash infra/scripts/setup-luharide-flutter-web-nginx.sh
#
# Docroot: /var/www/luharide-web  (must contain index.html from Flutter build/web)

set -euo pipefail

WEB_ROOT="/var/www/luharide-web"
SITE="/etc/nginx/sites-available/luharide-website"

if ! command -v nginx >/dev/null 2>&1; then
  echo "Install nginx: sudo apt install -y nginx"
  exit 1
fi

sudo mkdir -p "$WEB_ROOT"
if [[ ! -f "$WEB_ROOT/index.html" ]]; then
  echo "ERROR: No Flutter web build found at $WEB_ROOT/index.html"
  echo "Upload first: scp -r mobile/build/web/* root@this-server:$WEB_ROOT/"
  exit 1
fi

sudo chown -R www-data:www-data "$WEB_ROOT" 2>/dev/null || true

sudo tee "$SITE" >/dev/null <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name luharide.cloud www.luharide.cloud;

    root $WEB_ROOT;
    index index.html;

    # Flutter web SPA + hashed assets
    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
NGINX

sudo ln -sf "$SITE" /etc/nginx/sites-enabled/luharide-website
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "OK — https://luharide.cloud should run the Flutter app (after certbot)."
echo "If you still see old HTML: sudo rm -f /etc/nginx/sites-enabled/default"
echo "HTTPS: sudo certbot --nginx -d luharide.cloud -d www.luharide.cloud"
echo ""
