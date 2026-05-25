-- Migration 050: Optimized search index for 1M+ rides
-- The main search always filters: status='scheduled' + departure_time range + available_seats > 0
-- Adding available_seats > 0 to the partial index excludes fully-booked trips from the index entirely,
-- keeping it small and fast even at millions of total rows.

-- Backfill any NULL available_seats (legacy trips before migration 003)
UPDATE trips SET available_seats = total_capacity
  WHERE available_seats IS NULL AND total_capacity IS NOT NULL;

-- Partial covering index: only scheduled trips with open seats
-- B-tree on departure_time for range scans; INCLUDE avoids heap access for filtering
CREATE INDEX IF NOT EXISTS idx_trips_search_available
  ON trips(departure_time)
  INCLUDE (from_location_norm, to_location_norm, available_seats)
  WHERE status = 'scheduled' AND available_seats > 0;

-- Same for union_schedules
CREATE INDEX IF NOT EXISTS idx_union_sched_search_available
  ON union_schedules(departure_time)
  INCLUDE (from_location_norm, to_location_norm)
  WHERE status = 'scheduled';

-- Partial index on pending bookings for the auto-expiry cleanup job
CREATE INDEX IF NOT EXISTS idx_bookings_pending_created
  ON bookings(created_at)
  WHERE status = 'pending';
