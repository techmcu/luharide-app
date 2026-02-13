-- Add require_approval to trips (default true = driver must approve each booking)
ALTER TABLE trips ADD COLUMN IF NOT EXISTS require_approval BOOLEAN DEFAULT true;

-- Pending bookings don't reduce available_seats until approved
-- (handled in application logic)

COMMENT ON COLUMN trips.require_approval IS 'If true, driver must approve each booking. If false, auto-approve.';
