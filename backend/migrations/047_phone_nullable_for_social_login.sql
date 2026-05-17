-- Allow phone to be NULL for social login users (Google/Firebase)
-- who sign up without a phone number. They can add it later from profile.
ALTER TABLE users ALTER COLUMN phone DROP NOT NULL;

-- Drop the UNIQUE constraint, re-add it as a partial unique (only non-null, non-placeholder values)
-- This prevents duplicate real phone numbers while allowing multiple NULLs.
DROP INDEX IF EXISTS users_phone_key;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_phone_key;
CREATE UNIQUE INDEX IF NOT EXISTS users_phone_unique ON users(phone) WHERE phone IS NOT NULL AND phone NOT LIKE 'G%' AND phone NOT LIKE 'F%' AND phone NOT LIKE 'E%';

-- Clean up existing placeholder phones to NULL
UPDATE users SET phone = NULL WHERE phone ~ '^[GFE]\d+$';
