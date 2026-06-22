-- 064: Route polyline + bounding box for corridor ("along-route") matching.
--
-- Enables BlaBlaCar-style matching WITHOUT PostGIS: we store the ride's route
-- as a JSON line of [lat,lng] points, plus its bounding box for a cheap indexed
-- pre-filter. Search then refines candidates in app code (point-to-line distance
-- + travel-direction check).
--
-- SAFETY: all columns NULLABLE, ADD COLUMN IF NOT EXISTS, CREATE INDEX
-- IF NOT EXISTS — idempotent, no data touched. Rides without a polyline simply
-- fall back to endpoint-proximity matching.

-- ── trips ───────────────────────────────────────────────────────────────
ALTER TABLE trips ADD COLUMN IF NOT EXISTS route_polyline JSONB;          -- [[lat,lng],...]
ALTER TABLE trips ADD COLUMN IF NOT EXISTS route_min_lat NUMERIC(9,6);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS route_max_lat NUMERIC(9,6);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS route_min_lng NUMERIC(9,6);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS route_max_lng NUMERIC(9,6);

-- ── union_schedules ──────────────────────────────────────────────────────
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS route_polyline JSONB;
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS route_min_lat NUMERIC(9,6);
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS route_max_lat NUMERIC(9,6);
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS route_min_lng NUMERIC(9,6);
ALTER TABLE union_schedules ADD COLUMN IF NOT EXISTS route_max_lng NUMERIC(9,6);

-- ── Bounding-box pre-filter indexes ──────────────────────────────────────
-- Corridor query asks: route bbox (padded) overlaps the passenger's points,
-- i.e. route_min_lat <= P.lat <= route_max_lat (+pad) etc. A btree on the lat
-- bounds narrows the scan; the rest is finished by the lng bounds + JS refine.
-- Partial (only geo-tagged rides) keeps the index small.
CREATE INDEX IF NOT EXISTS idx_trips_route_bbox
  ON trips (route_min_lat, route_max_lat)
  WHERE route_polyline IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_union_schedules_route_bbox
  ON union_schedules (route_min_lat, route_max_lat)
  WHERE route_polyline IS NOT NULL;

COMMENT ON COLUMN trips.route_polyline IS 'Downsampled route line [[lat,lng],...] for corridor matching (no PostGIS).';
