-- 018_union_admins.sql
-- Simple mapping from users to unions as admins

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_name = 'union_admins'
  ) THEN
    CREATE TABLE union_admins (
      union_id UUID REFERENCES unions(id),
      user_id UUID REFERENCES users(id),
      PRIMARY KEY (union_id, user_id)
    );
  END IF;
END
$$;

