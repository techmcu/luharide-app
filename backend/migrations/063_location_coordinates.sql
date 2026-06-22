-- 063: Geo coordinates for trips & union schedules (Ola Maps integration)
--
-- Adds latitude/longitude for ride endpoints so we can do proximity ("rides
-- near me") search and road-distance fare estimation. Plus cached distance/
-- duration so we don't re-call the maps API for the same ride on every view.
--
-- SAFETY:
--  * All columns are NULLABLE — existing rides created before this migration
--    keep working unchanged (text-only search still functions; coords-based
--    ranking simply skips rows with NULL coords).
--  * ADD COLUMN IF NOT EXISTS + CREATE INDEX IF NOT EXISTS → fully idempotent,
--    safe to re-run, never touches/deletes existing data.
--  * NUMERIC(9,6): range ±999.999999, 6 decimals ≈ 0.11 m precision — covers
--    all valid lat (±90) / lng (±180) with room to spare.

-- ── trips ───────────────────────────────────────────────────────────────
ALTER TABLE trips ADD COLUMN IF NOT EXISTS from_lat NUMERIC(9,6);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS from_lng NUMERIC(9,6);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS to_lat   NUMERIC(9,6);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS to_lng   NUMERIC(9,6);
-- Cached route metrics (from Ola Directions, or Haversine fallback)
ALTER TABLE trips ADD COLUMN IF NOT EXISTS route_distance_km NUMERIC(6,1);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS route_duration_min INTEGER;

-- ── union_schedules ──────────────────────────────────────────────────────
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS from_lat NUMERIC(9,6);
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS from_lng NUMERIC(9,6);
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS to_lat   NUMERIC(9,6);
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS to_lng   NUMERIC(9,6);
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS route_distance_km NUMERIC(6,1);
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS route_duration_min INTEGER;

-- ── Indexes for proximity (bounding-box) pre-filter ──────────────────────
-- We pre-filter candidates with: from_lat BETWEEN ? AND ? AND from_lng BETWEEN ? AND ?
-- A composite btree on (from_lat, from_lng) serves the leading range scan.
-- Partial (WHERE NOT NULL) keeps the index small — only geo-tagged rides.
CREATE INDEX IF NOT EXISTS idx_trips_from_coords
  ON trips (from_lat, from_lng)
  WHERE from_lat IS NOT NULL AND from_lng IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_union_schedules_from_coords
  ON union_schedules (from_lat, from_lng)
  WHERE from_lat IS NOT NULL AND from_lng IS NOT NULL;

COMMENT ON COLUMN trips.from_lat IS 'Pickup latitude (Ola Maps). NULL for legacy text-only rides.';
COMMENT ON COLUMN trips.route_distance_km IS 'Cached road distance for fare/ETA; avoids repeat maps calls.';
