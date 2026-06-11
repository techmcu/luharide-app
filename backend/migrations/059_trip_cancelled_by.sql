-- Track WHO cancelled a trip (driver vs admin) so cancel count is fair.
-- Without this, admin-cancelled trips count against driver's cancel quota.

ALTER TABLE trips ADD COLUMN IF NOT EXISTS cancelled_by VARCHAR(20);

-- Backfill existing data: infer from booking cancellation_reason
UPDATE trips SET cancelled_by = 'admin'
WHERE status = 'cancelled' AND cancelled_by IS NULL
  AND id IN (
    SELECT DISTINCT trip_id FROM bookings
    WHERE cancellation_reason = 'Cancelled by platform admin'
  );

UPDATE trips SET cancelled_by = 'driver'
WHERE status = 'cancelled' AND cancelled_by IS NULL;

-- Optimized index for cancel count query (driver-only cancels in time window)
DROP INDEX IF EXISTS idx_trips_cancel_tracking;
CREATE INDEX idx_trips_cancel_tracking
  ON trips(driver_id, updated_at)
  WHERE status = 'cancelled' AND cancelled_by = 'driver';
