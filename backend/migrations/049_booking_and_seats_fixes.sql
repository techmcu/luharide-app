-- Fix C3: Allow rebooking after cancellation
-- Old: UNIQUE(trip_id, passenger_id) blocks rebooking even after cancel
-- New: partial unique index only on active (non-cancelled) bookings
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_trip_id_passenger_id_key;
DROP INDEX IF EXISTS bookings_trip_id_passenger_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_trip_passenger_active
  ON bookings(trip_id, passenger_id)
  WHERE status IN ('pending', 'confirmed');

-- Fix C4: Drop the trigger that silently overwrites available_seats
-- The app manages available_seats directly via atomic UPDATE queries in transactions.
-- The trigger was resetting available_seats = total_capacity - seats_booked on every UPDATE,
-- but the app never updates seats_booked, making all seat count changes a no-op.
DROP TRIGGER IF EXISTS trigger_update_available_seats ON trips;
DROP FUNCTION IF EXISTS update_available_seats();

-- Fix H13: Safety net — available_seats can never go negative
DO $$
BEGIN
  -- Fix any rows that are already negative before adding the constraint
  UPDATE trips SET available_seats = 0 WHERE available_seats < 0;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'check_available_seats_non_negative'
  ) THEN
    ALTER TABLE trips ADD CONSTRAINT check_available_seats_non_negative
      CHECK (available_seats >= 0);
  END IF;
END $$;

-- Fix C6: Unique index on users.email to prevent duplicate accounts + speed up lookups
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique
  ON users(email)
  WHERE email IS NOT NULL;

-- Fix: composite index for OTP lookups at scale
CREATE INDEX IF NOT EXISTS idx_otp_phone_verified
  ON otp_verifications(phone, is_verified)
  WHERE is_verified = FALSE;

CREATE INDEX IF NOT EXISTS idx_otp_email_verified
  ON otp_verifications(email, is_verified)
  WHERE email IS NOT NULL AND is_verified = FALSE;

-- Fix: composite index for getMyBookings performance at scale
CREATE INDEX IF NOT EXISTS idx_bookings_passenger_created
  ON bookings(passenger_id, created_at DESC);

-- Fix: index for booking status lookups on trip
CREATE INDEX IF NOT EXISTS idx_bookings_trip_status
  ON bookings(trip_id, status)
  WHERE status IN ('pending', 'confirmed');
