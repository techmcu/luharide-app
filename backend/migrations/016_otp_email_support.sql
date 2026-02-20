-- OTP via Email: add email column to otp_verifications, allow either phone or email

-- Make phone nullable so we can use email instead
ALTER TABLE otp_verifications ALTER COLUMN phone DROP NOT NULL;

-- Add email column
ALTER TABLE otp_verifications ADD COLUMN IF NOT EXISTS email VARCHAR(255) NULL;

-- Ensure exactly one of phone or email is set (application enforces; optional DB constraint)
-- CREATE INDEX for email lookups
CREATE INDEX IF NOT EXISTS idx_otp_email ON otp_verifications(email);

COMMENT ON COLUMN otp_verifications.email IS 'Email for email OTP; either phone or email must be set per row';
