-- 019_union_status.sql
-- Add status column to unions for approval workflow

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_name = 'unions'
      AND column_name = 'status'
  ) THEN
    ALTER TABLE unions
      ADD COLUMN status VARCHAR(20) DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected'));

    -- Backfill existing unions: treat active ones as approved
    UPDATE unions
    SET status = CASE
      WHEN is_active THEN 'approved'
      ELSE 'pending'
    END;
  END IF;
END
$$;

