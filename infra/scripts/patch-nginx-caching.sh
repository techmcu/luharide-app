#!/bin/bash
# Patch nginx config to add aggressive caching for Flutter web app
# Run on VPS after deployment to improve /app/ performance

set -e

SITE_CONF="/etc/nginx/sites-available/luharide-split"
MARKER="# LUHA_CACHING_V1"

if [ ! -f "$SITE_CONF" ]; then
    echo "ERROR: $SITE_CONF not found"
    exit 1
fi

if grep -q "$MARKER" "$SITE_CONF"; then
    echo "Caching rules already present, skipping..."
    exit 0
fi

echo "Adding aggressive caching rules for /app/ ..."

# Backup
cp "$SITE_CONF" "${SITE_CONF}.bak.$(date +%s)"

# Create patch content
cat > /tmp/luha-caching-patch.conf <<'PATCH_EOF'
    # LUHA_CACHING_V1 - Aggressive caching for Flutter web app performance
    location /app/ {
        alias /var/www/luharide-web/;
        try_files $uri $uri/ /app/index.html;
        
        # Cache static assets aggressively (JS, CSS, fonts, images, wasm)
        location ~ \.(js|css|woff2?|ttf|otf|eot|svg|png|jpg|jpeg|gif|ico|wasm)$ {
            alias /var/www/luharide-web/;
            expires 1y;
            add_header Cache-Control "public, immutable";
            access_log off;
        }
        
        # Cache JSON manifests for 1 hour
        location ~ \.(json)$ {
            alias /var/www/luharide-web/;
            expires 1h;
            add_header Cache-Control "public, must-revalidate";
        }
        
        # Don't cache index.html (always fresh for updates)
        location = /app/index.html {
            alias /var/www/luharide-web/index.html;
            expires -1;
            add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";
        }
    }
PATCH_EOF

# Find and replace the old simple /app/ location block
awk '
    BEGIN { in_app_block = 0; done = 0 }
    
    # Detect start of old /app/ block
    /location \/app\/ \{/ {
        if (!done) {
            in_app_block = 1
            # Read and output the patch file
            while ((getline line < "/tmp/luha-caching-patch.conf") > 0) {
                print line
            }
            close("/tmp/luha-caching-patch.conf")
            done = 1
            next
        }
    }
    
    # Skip lines until end of old block
    in_app_block && /^    \}/ {
        in_app_block = 0
        next
    }
    
    # Skip lines inside old block
    in_app_block { next }
    
    # Print all other lines
    { print }
    
    END {
        if (!done) {
            print "ERROR: Could not find location /app/ block" > "/dev/stderr"
            exit 1
        }
    }
' "$SITE_CONF" > "${SITE_CONF}.new"

if [ -s "${SITE_CONF}.new" ]; then
    mv "${SITE_CONF}.new" "$SITE_CONF"
    echo "✅ Caching rules added successfully"
    
    # Test nginx config
    nginx -t
    echo "✅ Nginx config test passed"
else
    echo "ERROR: Patched file empty, keeping original"
    rm -f "${SITE_CONF}.new"
    exit 1
fi

rm -f /tmp/luha-caching-patch.conf
echo "Done! Run: sudo systemctl reload nginx"
