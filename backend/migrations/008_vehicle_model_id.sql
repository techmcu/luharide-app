-- Migration: Add vehicle_model_id for exact seat layout
-- Driver verification + trips store vehicle catalog ID so passenger sees same layout as driver

-- Add vehicle_model_id to driver_verification_requests
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'driver_verification_requests' AND column_name = 'vehicle_model_id'
  ) THEN
    ALTER TABLE driver_verification_requests ADD COLUMN vehicle_model_id VARCHAR(50);
  END IF;
END $$;

-- Add vehicle_model_id to trips
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'trips' AND column_name = 'vehicle_model_id'
  ) THEN
    ALTER TABLE trips ADD COLUMN vehicle_model_id VARCHAR(50);
  END IF;
END $$;

COMMENT ON COLUMN driver_verification_requests.vehicle_model_id IS 'VehicleCatalog model ID e.g. mahindra_bolero_suv for exact seat layout';
COMMENT ON COLUMN trips.vehicle_model_id IS 'VehicleCatalog model ID - same layout as driver verification';
