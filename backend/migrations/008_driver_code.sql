-- 008_driver_code.sql
-- Add a short, shareable driver_code for verified drivers.
-- This is used so drivers can easily share a simple code with unions.

DO $$
BEGIN
  -- Add column if it does not exist
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'users'
      AND column_name = 'driver_code'
  ) THEN
    ALTER TABLE users
      ADD COLUMN driver_code VARCHAR(16);
  END IF;
END
$$;

-- Backfill existing approved drivers with a short code derived from their UUID
UPDATE users
SET driver_code = SUBSTRING(id::text, 1, 8)
WHERE driver_verification_status = 'approved'
  AND driver_code IS NULL;

-- Ensure quick lookup and uniqueness for non-null codes
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_driver_code
  ON users(driver_code)
  WHERE driver_code IS NOT NULL;

