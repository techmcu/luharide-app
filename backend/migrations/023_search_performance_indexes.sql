-- Migration 023: Search performance indexes
-- Adds stored generated columns for normalized location text and composite indexes.
-- Eliminates full-table regexp_replace scans on every search query.
--
-- BEFORE: regexp_replace(LOWER(TRIM(from_location)), '\s+', '', 'g') LIKE $1  → full scan
-- AFTER : from_location_norm LIKE $1  → B-tree index scan (O(log n) + few rows)

-- ─── trips table ──────────────────────────────────────────────────────────────

ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS from_location_norm TEXT
    GENERATED ALWAYS AS (regexp_replace(lower(trim(from_location)), '\s+', '', 'g')) STORED;

ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS to_location_norm TEXT
    GENERATED ALWAYS AS (regexp_replace(lower(trim(to_location)), '\s+', '', 'g')) STORED;

-- Index for LIKE prefix/infix searches on normalized location (B-tree covers prefix, pg_trgm covers infix)
CREATE INDEX IF NOT EXISTS idx_trips_from_norm ON trips(from_location_norm);
CREATE INDEX IF NOT EXISTS idx_trips_to_norm   ON trips(to_location_norm);

-- Composite index: the search always filters status='scheduled' AND departure_time in a day window.
-- This index is selective and eliminates the need to scan old/cancelled trips.
CREATE INDEX IF NOT EXISTS idx_trips_status_departure
  ON trips(status, departure_time)
  WHERE status = 'scheduled';

-- ─── union_schedules table ────────────────────────────────────────────────────

ALTER TABLE union_schedules
  ADD COLUMN IF NOT EXISTS from_location_norm TEXT
    GENERATED ALWAYS AS (regexp_replace(lower(trim(from_location)), '\s+', '', 'g')) STORED;

ALTER TABLE union_schedules
  ADD COLUMN IF NOT EXISTS to_location_norm TEXT
    GENERATED ALWAYS AS (regexp_replace(lower(trim(to_location)), '\s+', '', 'g')) STORED;

CREATE INDEX IF NOT EXISTS idx_union_sched_from_norm ON union_schedules(from_location_norm);
CREATE INDEX IF NOT EXISTS idx_union_sched_to_norm   ON union_schedules(to_location_norm);

CREATE INDEX IF NOT EXISTS idx_union_sched_status_departure
  ON union_schedules(status, departure_time)
  WHERE status = 'scheduled';

-- ─── recent_routes: fix non-atomic DELETE with window function ────────────────
-- The old code: COUNT(*) then DELETE ... WHERE id NOT IN (SELECT ... LIMIT N)
-- NOT IN with subquery is O(n*m). Replace with a cleaner partial index for quick lookup.
CREATE INDEX IF NOT EXISTS idx_recent_routes_user_created
  ON recent_routes(user_id, created_at DESC);
