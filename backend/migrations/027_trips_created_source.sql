-- Distinguish independent (driver app) trips from union-created trips for rate-notification timing.
ALTER TABLE trips ADD COLUMN IF NOT EXISTS created_source VARCHAR(32);

COMMENT ON COLUMN trips.created_source IS 'independent_driver = POST /api/trips; union_admin = POST /api/union/trips; NULL = legacy (treat as union-style scheduling)';
