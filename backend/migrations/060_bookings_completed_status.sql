-- Add 'completed' to bookings status check constraint.
-- The constraint only allowed (pending, confirmed, cancelled) but multiple jobs
-- and controllers set status = 'completed' when a trip finishes.

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;

ALTER TABLE bookings ADD CONSTRAINT bookings_status_check
  CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled'));
