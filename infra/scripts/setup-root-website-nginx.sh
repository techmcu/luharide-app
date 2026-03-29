#!/usr/bin/env bash
# OPTIONAL: lightweight static marketing page only.
# For the real app UI (same as APK) use Flutter Web + setup-luharide-flutter-web-nginx.sh
#
# Run ON THE VPS (after: git pull in repo clone):
#   chmod +x infra/scripts/setup-root-website-nginx.sh
#   sudo ./infra/scripts/setup-root-website-nginx.sh
#
# Does: copy landing HTML → /var/www/luharide-cloud, enable nginx site for
#       luharide.cloud + www (static only). api.luharide.cloud unchanged.
#
# If https://luharide.cloud still shows API JSON, remove any other site that
# proxies server_name luharide.cloud to :3000 (check sites-enabled/).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC="$REPO_ROOT/infra/static-site-luharide-root/index.html"
TARGET="/var/www/luharide-cloud"
SITE="/etc/nginx/sites-available/luharide-website"

if [[ ! -f "$SRC" ]]; then
  echo "Missing: $SRC (run from repo clone on VPS after git pull)"
  exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
  echo "Install nginx first: sudo apt install -y nginx"
  exit 1
fi

sudo mkdir -p "$TARGET"
sudo cp "$SRC" "$TARGET/index.html"
sudo chown -R www-data:www-data "$TARGET" 2>/dev/null || true

sudo tee "$SITE" >/dev/null <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name luharide.cloud www.luharide.cloud;

    root /var/www/luharide-cloud;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

sudo ln -sf "$SITE" /etc/nginx/sites-enabled/luharide-website
sudo nginx -t
sudo systemctl reload nginx

echo ""
echo "OK — http://luharide.cloud/ should show the LuhaRide landing page."
echo "HTTPS:  sudo certbot --nginx -d luharide.cloud -d www.luharide.cloud"
echo ""
