-- Fix FK constraints that block trip deletion when dependent rows exist.
-- Add missing indexes for cleanup-job performance.

-- ── location_history: CASCADE on trip deletion (GPS data is meaningless without trip) ──
ALTER TABLE location_history DROP CONSTRAINT IF EXISTS location_history_trip_id_fkey;
ALTER TABLE location_history
  ADD CONSTRAINT location_history_trip_id_fkey
  FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE;

ALTER TABLE location_history DROP CONSTRAINT IF EXISTS location_history_driver_id_fkey;
ALTER TABLE location_history
  ADD CONSTRAINT location_history_driver_id_fkey
  FOREIGN KEY (driver_id) REFERENCES users(id) ON DELETE CASCADE;

-- ── sos_logs: SET NULL on trip/booking deletion (safety records outlive trips) ──
ALTER TABLE sos_logs DROP CONSTRAINT IF EXISTS sos_logs_trip_id_fkey;
ALTER TABLE sos_logs ALTER COLUMN trip_id DROP NOT NULL;
ALTER TABLE sos_logs
  ADD CONSTRAINT sos_logs_trip_id_fkey
  FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE SET NULL;

ALTER TABLE sos_logs DROP CONSTRAINT IF EXISTS sos_logs_booking_id_fkey;
ALTER TABLE sos_logs
  ADD CONSTRAINT sos_logs_booking_id_fkey
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

-- ── complaints.resolved_by: SET NULL if admin deleted ──
ALTER TABLE complaints DROP CONSTRAINT IF EXISTS complaints_resolved_by_fkey;
ALTER TABLE complaints
  ADD CONSTRAINT complaints_resolved_by_fkey
  FOREIGN KEY (resolved_by) REFERENCES users(id) ON DELETE SET NULL;

-- ── notifications: index on created_at for cleanup job (avoids full scan) ──
CREATE INDEX IF NOT EXISTS idx_notifications_created_at
  ON notifications(created_at);

-- ── notifications: partial index for unread cleanup ──
CREATE INDEX IF NOT EXISTS idx_notifications_read_created
  ON notifications(created_at)
  WHERE is_read = TRUE;

-- ── union_daily_actions: index on created_at for age-based cleanup ──
CREATE INDEX IF NOT EXISTS idx_union_daily_actions_created
  ON union_daily_actions(created_at);

-- ── fcm_tokens: index on updated_at for cleanup job ──
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_updated_at
  ON fcm_tokens(updated_at);

-- ── pending_rate_notifications: index on created_at for cleanup ──
CREATE INDEX IF NOT EXISTS idx_pending_rate_created_at
  ON pending_rate_notifications(created_at);

-- ── refresh_tokens: composite index for cleanup query ──
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_cleanup
  ON refresh_tokens(expires_at)
  WHERE is_revoked = FALSE;

-- ── trips: available_seats upper bound safety net ──
-- Prevent available_seats from exceeding total_capacity due to double seat-restoration bugs.
-- Fix any existing violations first.
UPDATE trips SET available_seats = total_capacity
  WHERE available_seats IS NOT NULL AND total_capacity IS NOT NULL
    AND available_seats > total_capacity;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_available_seats_upper_bound'
  ) THEN
    ALTER TABLE trips ADD CONSTRAINT check_available_seats_upper_bound
      CHECK (available_seats IS NULL OR total_capacity IS NULL OR available_seats <= total_capacity);
  END IF;
END $$;
