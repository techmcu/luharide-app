#!/usr/bin/env bash
# =============================================================================
# LuhaRide — FULL data flush (PostgreSQL + upload files on disk)
# =============================================================================
# Wipes ALL rows from application tables (users, trips, KYC refs, etc.) and
# deletes files under backend/uploads/* (driver-docs, union-raw, merged PDFs…).
#
# Does NOT truncate ms_table_domain (microservice metadata — safe to keep).
# Does NOT run migrations or drop tables.
#
# VPS example:
#   cd /var/www/luharide-backend/backend
#   set -a && . ./.env && set +a
#   CONFIRM_FULL_FLUSH=YES ./scripts/full-flush-luharide-data.sh
#
# Optional: flush Redis DB used by Socket.IO / rate limit (uncomment section).
# =============================================================================

set -euo pipefail

if [[ "${CONFIRM_FULL_FLUSH:-}" != "YES" ]]; then
  echo "Refusing to run: set CONFIRM_FULL_FLUSH=YES"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${BACKEND_ROOT}"

if [[ ! -f ./.env ]]; then
  echo "No .env in ${BACKEND_ROOT}"
  exit 1
fi

set -a
set +u
# shellcheck disable=SC1091
source ./.env
set -u
set +a

: "${DB_PASSWORD:?DB_PASSWORD missing in .env}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-luharide}"

export PGPASSWORD="${DB_PASSWORD}"

echo "==> PostgreSQL: TRUNCATE all app tables in database '${DB_NAME}' (CASCADE)…"

psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
-- App data only. Keep ms_table_domain (migration 029 metadata).
TRUNCATE TABLE
  ride_ratings,
  pending_rate_notifications,
  reviews,
  payments,
  otp_verifications,
  refresh_tokens,
  login_history,
  emergency_contacts,
  recent_routes,
  driver_verification_requests,
  driver_documents,
  location_history,
  sos_logs,
  notifications,
  bookings,
  trips,
  vehicles,
  union_admins,
  union_drivers,
  union_routes,
  union_schedules,
  unions,
  routes,
  users,
  settings
RESTART IDENTITY CASCADE;
COMMIT;
SQL

unset PGPASSWORD

echo "==> Uploads: removing KYC files under ${BACKEND_ROOT}/uploads …"
UPLOADS="${BACKEND_ROOT}/uploads"
mkdir -p "$UPLOADS/driver-docs" "$UPLOADS/union-raw" "$UPLOADS/union-merged" "$UPLOADS/union-docs"
for sub in driver-docs union-raw union-merged union-docs; do
  dir="$UPLOADS/$sub"
  if [[ -d "$dir" ]]; then
    find "$dir" -mindepth 1 -delete 2>/dev/null || true
  fi
done
find "$UPLOADS" -maxdepth 1 -type f -delete 2>/dev/null || true

echo "==> Done. DB rows cleared; KYC/upload folders emptied."

# --- Optional: Redis (Socket.IO adapter / rate limits). Uncomment if you use Redis.
# REDIS_CLI=$(command -v redis-cli || true)
# if [[ -n "$REDIS_CLI" && -n "${REDIS_URL:-}" ]]; then
#   echo "==> Flushing Redis per REDIS_URL (careful in prod)…"
#   redis-cli -u "$REDIS_URL" FLUSHDB
# fi
