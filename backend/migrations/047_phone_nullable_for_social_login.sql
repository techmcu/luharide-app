-- Allow phone to be NULL for social login users (Google/Firebase)
-- who sign up without a phone number. They can add it later from profile.
ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;

-- Drop the UNIQUE constraint first (index depends on it), then re-add as partial unique.
-- This prevents duplicate real phone numbers while allowing multiple NULLs.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_phone_key;
DROP INDEX IF EXISTS users_phone_key;
CREATE UNIQUE INDEX IF NOT EXISTS users_phone_unique ON users(phone) WHERE phone IS NOT NULL AND phone NOT LIKE 'G%' AND phone NOT LIKE 'F%' AND phone NOT LIKE 'E%';

-- Clean up existing placeholder phones to NULL
UPDATE users SET phone = NULL WHERE phone ~ '^[GFE]\d+$';
