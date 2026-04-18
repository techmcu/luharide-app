#!/bin/bash
# Emergency fix: Remove duplicate client_max_body_size from nginx config
# Run on VPS if deployment fails with duplicate directive error

set -e

SITE_CONF="/etc/nginx/sites-available/luharide-split"

if [ ! -f "$SITE_CONF" ]; then
    echo "ERROR: $SITE_CONF not found"
    exit 1
fi

echo "Checking for duplicate client_max_body_size directives..."

# Count occurrences in the luharide.cloud server block
COUNT=$(grep -c "client_max_body_size" "$SITE_CONF" || true)

if [ "$COUNT" -le 1 ]; then
    echo "✅ No duplicate found. Config is clean."
    exit 0
fi

echo "⚠️  Found $COUNT occurrences of client_max_body_size"

# Backup
cp "$SITE_CONF" "${SITE_CONF}.bak.emergency.$(date +%s)"

# Remove duplicate: Keep only the FIRST occurrence in server block
# This awk script keeps the first client_max_body_size and removes others
awk '
    BEGIN { found = 0; in_server = 0 }
    
    # Track if we are in luharide.cloud server block
    /server_name luharide.cloud/ { in_server = 1 }
    /^}/ { in_server = 0 }
    
    # If this line has client_max_body_size
    /client_max_body_size/ {
        if (in_server && found == 0) {
            # First occurrence in luharide.cloud block - keep it
            found = 1
            print
            next
        } else if (in_server && found == 1) {
            # Duplicate in same block - skip it
            print "    # (duplicate client_max_body_size removed by cleanup script)"
            next
        } else {
            # In api.luharide.cloud block - keep it
            print
            next
        }
    }
    
    # Print all other lines
    { print }
' "$SITE_CONF" > "${SITE_CONF}.cleaned"

if [ -s "${SITE_CONF}.cleaned" ]; then
    mv "${SITE_CONF}.cleaned" "$SITE_CONF"
    echo "✅ Cleaned nginx config"
    
    # Test
    nginx -t
    echo "✅ Nginx config test passed"
    echo "Run: sudo systemctl reload nginx"
else
    echo "ERROR: Cleaned file empty"
    rm -f "${SITE_CONF}.cleaned"
    exit 1
fi
