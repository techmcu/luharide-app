-- 026_union_documents.sql
-- Add basic document fields for union registration (owner + office docs)

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'unions' AND column_name = 'owner_name'
  ) THEN
    ALTER TABLE unions
      ADD COLUMN owner_name VARCHAR(200),
      ADD COLUMN owner_aadhaar_url TEXT,
      ADD COLUMN office_photo_url TEXT,
      ADD COLUMN owner_vehicle_rc_url TEXT;
  END IF;
END
$$;

