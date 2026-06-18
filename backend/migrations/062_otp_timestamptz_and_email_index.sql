-- OTP hardening: make expiry timezone-correct and speed up email lookups.
--
-- 1) Convert otp_verifications timestamp columns to TIMESTAMPTZ so expiry is an
--    absolute instant, not a wall-clock that depends on the session timezone.
--    Existing values were written as UTC instants, so reinterpret them AS UTC.
--    Guarded so it is a no-op if already timestamptz (safe to re-run).
-- 2) Index on email — verify/create look up OTP rows by email; without an index
--    this is a sequential scan that gets slower as the table grows.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'otp_verifications' AND column_name = 'expires_at'
      AND data_type = 'timestamp without time zone'
  ) THEN
    ALTER TABLE otp_verifications
      ALTER COLUMN expires_at TYPE timestamptz USING expires_at AT TIME ZONE 'UTC';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'otp_verifications' AND column_name = 'created_at'
      AND data_type = 'timestamp without time zone'
  ) THEN
    ALTER TABLE otp_verifications
      ALTER COLUMN created_at TYPE timestamptz USING created_at AT TIME ZONE 'UTC';
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'otp_verifications' AND column_name = 'verified_at'
      AND data_type = 'timestamp without time zone'
  ) THEN
    ALTER TABLE otp_verifications
      ALTER COLUMN verified_at TYPE timestamptz USING verified_at AT TIME ZONE 'UTC';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_otp_email ON otp_verifications(email);
