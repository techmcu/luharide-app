-- Fix: OTP column is VARCHAR(6) but code stores SHA-256 HMAC hashes (64 chars).
-- INSERT fails with "value too long" → caught as "Failed to generate OTP".
ALTER TABLE otp_verifications ALTER COLUMN otp TYPE VARCHAR(128);
