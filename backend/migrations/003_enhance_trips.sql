-- Enhancement for trips table to support direct trip creation by drivers
-- without requiring pre-existing routes/vehicles

-- Add new columns to trips table
ALTER TABLE trips 
  ADD COLUMN IF NOT EXISTS from_location VARCHAR(200),
  ADD COLUMN IF NOT EXISTS to_location VARCHAR(200),
  ADD COLUMN IF NOT EXISTS vehicle_number VARCHAR(20),
  ADD COLUMN IF NOT EXISTS available_seats INTEGER DEFAULT 7,
  ADD COLUMN IF NOT EXISTS stops JSONB DEFAULT '[]'::jsonb;

-- Make route_id and vehicle_id optional (for direct trip creation)
ALTER TABLE trips 
  ALTER COLUMN route_id DROP NOT NULL,
  ALTER COLUMN vehicle_id DROP NOT NULL;

-- Add check constraint for location
ALTER TABLE trips 
  ADD CONSTRAINT check_location_or_route 
  CHECK (
    (from_location IS NOT NULL AND to_location IS NOT NULL) 
    OR route_id IS NOT NULL
  );

-- Update existing trips to have available_seats
UPDATE trips 
SET available_seats = total_capacity - seats_booked 
WHERE available_seats IS NULL;

-- Create index for search performance
CREATE INDEX IF NOT EXISTS idx_trips_locations ON trips(from_location, to_location);
CREATE INDEX IF NOT EXISTS idx_trips_departure ON trips(departure_time);
CREATE INDEX IF NOT EXISTS idx_trips_status ON trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_driver ON trips(driver_id);

-- Add trigger to update available_seats
CREATE OR REPLACE FUNCTION update_available_seats()
RETURNS TRIGGER AS $$
BEGIN
  NEW.available_seats := NEW.total_capacity - NEW.seats_booked;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_available_seats
BEFORE INSERT OR UPDATE ON trips
FOR EACH ROW
EXECUTE FUNCTION update_available_seats();

COMMENT ON COLUMN trips.from_location IS 'Direct location name (used when route_id is null)';
COMMENT ON COLUMN trips.to_location IS 'Direct location name (used when route_id is null)';
COMMENT ON COLUMN trips.vehicle_number IS 'Direct vehicle number (used when vehicle_id is null)';
COMMENT ON COLUMN trips.stops IS 'JSON array of stop names along the route';
