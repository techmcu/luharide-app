-- Trip started_at: when driver clicks "Start ride" (for rating rule: allow 2 min after start)
ALTER TABLE trips
  ADD COLUMN IF NOT EXISTS started_at TIMESTAMP WITH TIME ZONE;

COMMENT ON COLUMN trips.started_at IS 'Set when driver starts ride; rating allowed 2 min after this';
