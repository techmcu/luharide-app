-- Enforce email uniqueness at DB level to prevent race-condition duplicate accounts.
-- Step 1: Deduplicate any existing rows (keep the oldest account per email).
DO $$
DECLARE
  _dup RECORD;
BEGIN
  FOR _dup IN
    SELECT id, email FROM (
      SELECT id, email,
             ROW_NUMBER() OVER (PARTITION BY lower(email) ORDER BY created_at ASC) AS rn
      FROM users
      WHERE email IS NOT NULL
    ) sub
    WHERE rn > 1
  LOOP
    RAISE NOTICE 'Deactivating duplicate user id=% email=%', _dup.id, _dup.email;
    UPDATE users SET is_active = FALSE, email = _dup.email || ':dup:' || _dup.id
    WHERE id = _dup.id;
  END LOOP;
END $$;

-- Step 2: Create partial unique index on lowercased email.
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique
  ON users(lower(email))
  WHERE email IS NOT NULL;
