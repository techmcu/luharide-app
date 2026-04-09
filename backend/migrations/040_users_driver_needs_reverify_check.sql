-- Allow needs_reverify on users.driver_verification_status (admin re-upload flow).
-- Original 007 migration only allowed none|pending|approved|rejected, which could block
-- grantDriverReverify / needs_reverify updates on some PostgreSQL setups.

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.conname
    FROM pg_constraint c
    JOIN pg_class t ON c.conrelid = t.oid
    WHERE t.relname = 'users'
      AND c.contype = 'c'
      AND pg_get_constraintdef(c.oid) LIKE '%driver_verification_status%'
  LOOP
    EXECUTE format('ALTER TABLE users DROP CONSTRAINT %I', r.conname);
  END LOOP;
END $$;

ALTER TABLE users
  ADD CONSTRAINT users_driver_verification_status_check
  CHECK (
    driver_verification_status IN (
      'none',
      'pending',
      'approved',
      'rejected',
      'needs_reverify'
    )
  );
