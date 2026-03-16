-- Migration 025: Load scaling and query optimization indexes
-- Reduces server load by speeding up frequent queries (bookings, location suggestions).

-- ─── bookings: composite index for trip_id + status ─────────────────────────
-- Used by: getTripBookedSeats, getMyTrips subquery, seat availability checks
CREATE INDEX IF NOT EXISTS idx_bookings_trip_status
  ON bookings(trip_id, status)
  WHERE status IN ('confirmed', 'pending');

-- ─── trips: expression indexes for location suggestions ──────────────────────
-- getLocationSuggestions: SELECT ... WHERE LOWER(location) LIKE LOWER($1)
-- Helps when planner uses index scan on from_location / to_location
CREATE INDEX IF NOT EXISTS idx_trips_from_location_lower ON trips(LOWER(from_location));
CREATE INDEX IF NOT EXISTS idx_trips_to_location_lower ON trips(LOWER(to_location));
