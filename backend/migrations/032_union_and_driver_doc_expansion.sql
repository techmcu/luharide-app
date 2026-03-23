-- Expand union/driver document fields and poster theme.
-- Backward-compatible: existing fields remain unchanged.

ALTER TABLE unions
  ADD COLUMN IF NOT EXISTS poster_theme VARCHAR(20),
  ADD COLUMN IF NOT EXISTS owner_aadhaar_front_url TEXT,
  ADD COLUMN IF NOT EXISTS owner_aadhaar_back_url TEXT,
  ADD COLUMN IF NOT EXISTS owner_vehicle_rc_front_url TEXT,
  ADD COLUMN IF NOT EXISTS owner_vehicle_rc_back_url TEXT,
  ADD COLUMN IF NOT EXISTS leader_driving_license_front_url TEXT,
  ADD COLUMN IF NOT EXISTS leader_driving_license_back_url TEXT,
  ADD COLUMN IF NOT EXISTS union_photo_url TEXT,
  ADD COLUMN IF NOT EXISTS union_driver_list_photo_url TEXT;

ALTER TABLE unions
  DROP CONSTRAINT IF EXISTS unions_poster_theme_check;

ALTER TABLE unions
  ADD CONSTRAINT unions_poster_theme_check
  CHECK (
    poster_theme IS NULL OR
    poster_theme IN ('saffron', 'sky', 'mint', 'rose')
  );

ALTER TABLE driver_verification_requests
  ADD COLUMN IF NOT EXISTS aadhaar_front_url TEXT,
  ADD COLUMN IF NOT EXISTS aadhaar_back_url TEXT,
  ADD COLUMN IF NOT EXISTS rc_front_url TEXT,
  ADD COLUMN IF NOT EXISTS rc_back_url TEXT,
  ADD COLUMN IF NOT EXISTS driving_license_front_url TEXT,
  ADD COLUMN IF NOT EXISTS driving_license_back_url TEXT;
