-- Track cancellation history for drivers and passengers.
-- Enables soft-block for repeat offenders (BlaBlaCar-style).

-- Driver: cancel_count on users table (rolling 30-day window checked in code)
ALTER TABLE users ADD COLUMN IF NOT EXISTS cancel_count INT DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS cancel_blocked_until TIMESTAMP;

-- Passenger: same columns (already on users table)
-- cancel_count = how many times cancelled in recent window
-- cancel_blocked_until = if set and > NOW(), user is temporarily blocked from booking/creating

CREATE INDEX IF NOT EXISTS idx_bookings_cancel_tracking
  ON bookings(passenger_id, cancelled_at)
  WHERE status = 'cancelled' AND cancellation_reason NOT LIKE 'auto-%';

CREATE INDEX IF NOT EXISTS idx_trips_cancel_tracking
  ON trips(driver_id, updated_at)
  WHERE status = 'cancelled';
