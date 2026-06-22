-- 065: Coordinates on union_routes (permanent fix for union ride geocoding).
--
-- Union routes stored only text, so creating rides had to GEOCODE the text —
-- ambiguous, sometimes resolving to a same-named place in another city/state.
-- Now the union admin picks the place (with coordinates) when creating the
-- route; those exact coords are stored and reused for every ride on the route —
-- no guessing, correct lat/lng every time.
--
-- SAFETY: nullable, ADD COLUMN IF NOT EXISTS, idempotent. Existing routes keep
-- working (ride creation falls back to region-biased geocoding when coords absent).

ALTER TABLE union_routes ADD COLUMN IF NOT EXISTS from_lat NUMERIC(9,6);
ALTER TABLE union_routes ADD COLUMN IF NOT EXISTS from_lng NUMERIC(9,6);
ALTER TABLE union_routes ADD COLUMN IF NOT EXISTS to_lat   NUMERIC(9,6);
ALTER TABLE union_routes ADD COLUMN IF NOT EXISTS to_lng   NUMERIC(9,6);

COMMENT ON COLUMN union_routes.from_lat IS 'Pickup latitude chosen at route creation (Ola picker). NULL = legacy route, geocoded on ride create.';
