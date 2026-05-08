-- Migration 041: Trigram indexes for fast LIKE '%pattern%' searches
-- B-tree indexes only help with prefix LIKE ('pattern%'), not contains ('%pattern%').
-- pg_trgm GIN indexes enable fast substring matching at scale (100+ unions, 1000+ concurrent searches).

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ─── trips: GIN trigram indexes on normalized location columns ───────────────
CREATE INDEX IF NOT EXISTS idx_trips_from_norm_trgm
  ON trips USING GIN (from_location_norm gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_trips_to_norm_trgm
  ON trips USING GIN (to_location_norm gin_trgm_ops);

-- ─── union_schedules: same treatment ────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_union_sched_from_norm_trgm
  ON union_schedules USING GIN (from_location_norm gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_union_sched_to_norm_trgm
  ON union_schedules USING GIN (to_location_norm gin_trgm_ops);

-- ─── Composite covering index for the main search hot path ──────────────────
-- The search always filters: status='scheduled' + departure_time range + available_seats > 0
-- This covering index lets PG answer the query from the index without heap access for filtering.
CREATE INDEX IF NOT EXISTS idx_trips_scheduled_search
  ON trips(departure_time)
  INCLUDE (from_location_norm, to_location_norm, available_seats, total_capacity)
  WHERE status = 'scheduled';

-- ─── union_schedules: same covering index ───────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_union_sched_scheduled_search
  ON union_schedules(departure_time)
  INCLUDE (from_location_norm, to_location_norm)
  WHERE status = 'scheduled';
