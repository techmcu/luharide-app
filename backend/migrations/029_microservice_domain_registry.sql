-- Migration 029: Microservice domain boundaries (metadata only — single DB, public schema unchanged)
-- LuhaRide v1: all services share one PostgreSQL; this migration documents & queries ownership.
-- Does NOT move tables (would break unqualified SQL in Node). Future: extract services + schemas.

-- Logical schemas (empty): reserved for future GRANT / search_path per service or documentation tools
CREATE SCHEMA IF NOT EXISTS ms_auth;
CREATE SCHEMA IF NOT EXISTS ms_core;
CREATE SCHEMA IF NOT EXISTS ms_union;
CREATE SCHEMA IF NOT EXISTS ms_platform;
CREATE SCHEMA IF NOT EXISTS ms_shared;

COMMENT ON SCHEMA ms_auth IS 'Logical domain: auth microservice (tokens, OTP, login audit). Tables remain in public until split.';
COMMENT ON SCHEMA ms_core IS 'Logical domain: core microservice (trips, bookings, drivers, driver verification).';
COMMENT ON SCHEMA ms_union IS 'Logical domain: union microservice (union entities & schedules).';
COMMENT ON SCHEMA ms_platform IS 'Logical domain: platform microservice (payments, notifications, reviews, admin settings).';
COMMENT ON SCHEMA ms_shared IS 'Logical domain: cross-cutting tables (e.g. users identity).';

-- Registry: queryable mapping for audits, codegen, and future DB-per-service extraction
CREATE TABLE IF NOT EXISTS ms_table_domain (
  table_name TEXT PRIMARY KEY,
  primary_service TEXT NOT NULL
    CHECK (primary_service IN ('auth', 'core', 'union', 'platform', 'shared')),
  related_services TEXT[] DEFAULT '{}',
  description TEXT
);

COMMENT ON TABLE ms_table_domain IS 'Primary owning microservice for each public table (v1 shared database).';

INSERT INTO ms_table_domain (table_name, primary_service, related_services, description) VALUES
  ('users', 'shared', ARRAY['auth','core','union','platform']::text[],
   'Identity: credentials, profile, roles; referenced by all services.'),
  ('otp_verifications', 'auth', ARRAY[]::text[], 'Phone/email OTP for login and signup.'),
  ('refresh_tokens', 'auth', ARRAY[]::text[], 'JWT refresh token storage.'),
  ('login_history', 'auth', ARRAY[]::text[], 'Login attempts and audit.'),
  ('emergency_contacts', 'auth', ARRAY['core']::text[], 'User emergency contacts (SOS-related).'),

  ('routes', 'core', ARRAY['union']::text[], 'Canonical routes for trip search and matching.'),
  ('vehicles', 'core', ARRAY['union']::text[], 'Registered vehicles.'),
  ('trips', 'core', ARRAY['union']::text[], 'Scheduled / active trips (driver & union sources).'),
  ('bookings', 'core', ARRAY['platform']::text[], 'Seat bookings; payments/reviews reference this.'),
  ('location_history', 'core', ARRAY[]::text[], 'GPS trail during trips.'),
  ('sos_logs', 'core', ARRAY['platform']::text[], 'Emergency SOS events.'),
  ('driver_documents', 'core', ARRAY[]::text[], 'Legacy/supplemental driver document rows.'),
  ('driver_verification_requests', 'core', ARRAY['platform']::text[], 'Driver onboarding workflow; admin may review via platform.'),
  ('pending_rate_notifications', 'core', ARRAY['platform']::text[], 'Deferred rating reminders (cron in core service).'),
  ('recent_routes', 'core', ARRAY[]::text[], 'Passenger recent route hints for UX.'),

  ('unions', 'union', ARRAY['core']::text[], 'Taxi union registry and metadata.'),
  ('union_admins', 'union', ARRAY[]::text[], 'Union admin membership.'),
  ('union_drivers', 'union', ARRAY['core']::text[], 'Union-managed driver directory.'),
  ('union_routes', 'union', ARRAY['core']::text[], 'Union route definitions.'),
  ('union_schedules', 'union', ARRAY['core']::text[], 'Union schedule instances for search.'),

  ('payments', 'platform', ARRAY['core']::text[], 'Payment records linked to bookings.'),
  ('reviews', 'platform', ARRAY['core']::text[], 'Post-ride reviews.'),
  ('ride_ratings', 'platform', ARRAY['core']::text[], 'Rating aggregates / ride ratings.'),
  ('notifications', 'platform', ARRAY['core']::text[], 'In-app notifications per user.'),
  ('settings', 'platform', ARRAY[]::text[], 'Global platform configuration (admin).')
ON CONFLICT (table_name) DO UPDATE SET
  primary_service = EXCLUDED.primary_service,
  related_services = EXCLUDED.related_services,
  description = EXCLUDED.description;

CREATE OR REPLACE VIEW v_ms_tables_by_service AS
SELECT primary_service, table_name, related_services, description
FROM ms_table_domain
ORDER BY primary_service, table_name;

COMMENT ON VIEW v_ms_tables_by_service IS 'Convenient listing of tables grouped by owning microservice.';
