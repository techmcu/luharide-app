-- Keep ride_ratings when bookings/trips are purged: reviews are permanent trust data.
-- booking_id becomes nullable; FK uses ON DELETE SET NULL.
-- trip_context stores route snapshot for UI when booking row is gone.

ALTER TABLE ride_ratings ADD COLUMN IF NOT EXISTS trip_context TEXT;

COMMENT ON COLUMN ride_ratings.trip_context IS 'Snapshot e.g. "From → To" when booking/trip deleted; never cleared by retention job';

ALTER TABLE ride_ratings DROP CONSTRAINT IF EXISTS ride_ratings_booking_id_fkey;

ALTER TABLE ride_ratings ALTER COLUMN booking_id DROP NOT NULL;

UPDATE ride_ratings SET booking_id = NULL
WHERE booking_id IS NOT NULL
  AND booking_id NOT IN (SELECT id FROM bookings);

ALTER TABLE ride_ratings
  ADD CONSTRAINT ride_ratings_booking_id_fkey
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL;
