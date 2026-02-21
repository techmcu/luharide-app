-- Ensure trips table allows direct creation by drivers (no vehicle_id/route_id required).
-- Run this if rides are not saving: npm run migrate (or run this file).
-- Makes vehicle_id and route_id nullable so INSERT with only from_location/to_location works.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'vehicle_id') THEN
    ALTER TABLE trips ALTER COLUMN vehicle_id DROP NOT NULL;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'trips' AND column_name = 'route_id') THEN
    ALTER TABLE trips ALTER COLUMN route_id DROP NOT NULL;
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Ensure direct-create columns exist
ALTER TABLE trips ADD COLUMN IF NOT EXISTS from_location VARCHAR(200);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS to_location VARCHAR(200);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS vehicle_number VARCHAR(20);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS available_seats INTEGER DEFAULT 7;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS stops JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN trips.from_location IS 'Direct location (driver create trip)';
COMMENT ON COLUMN trips.to_location IS 'Direct location (driver create trip)';
