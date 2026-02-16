-- When booking becomes confirmed we store the time; rating allowed 4 min after this
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN bookings.confirmed_at IS 'Set when status becomes confirmed; rating allowed 4 min after this';
