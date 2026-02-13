-- Fix trips table for easy ride creation

-- Add total_seats column if missing
ALTER TABLE trips 
ADD COLUMN IF NOT EXISTS total_seats INTEGER DEFAULT 7;

-- Make sure total_capacity exists (old column name)
ALTER TABLE trips 
ADD COLUMN IF NOT EXISTS total_capacity INTEGER;

-- Copy total_capacity to total_seats if needed
UPDATE trips 
SET total_seats = COALESCE(total_capacity, 7)
WHERE total_seats IS NULL;

-- Make route_id and vehicle_id optional (already done but ensure)
ALTER TABLE trips 
ALTER COLUMN route_id DROP NOT NULL;

ALTER TABLE trips 
ALTER COLUMN vehicle_id DROP NOT NULL;

-- Update available_seats to match total_seats for new trips
UPDATE trips 
SET available_seats = total_seats
WHERE available_seats IS NULL OR available_seats = 0;
