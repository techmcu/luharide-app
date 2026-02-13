-- Fix total_capacity constraint

-- Make total_capacity nullable
ALTER TABLE trips 
ALTER COLUMN total_capacity DROP NOT NULL;

-- Set default value
ALTER TABLE trips 
ALTER COLUMN total_capacity SET DEFAULT 7;

-- Update existing NULL values
UPDATE trips 
SET total_capacity = COALESCE(total_seats, 7)
WHERE total_capacity IS NULL;
