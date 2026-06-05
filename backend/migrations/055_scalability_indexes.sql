-- Plain B-tree index on users.email so email lookups don't require lower() wrapper.
-- The existing idx_users_email_unique is a functional index on lower(email) — PostgreSQL
-- won't use it for plain WHERE email = $1 queries, causing seq scans under load.
CREATE INDEX IF NOT EXISTS idx_users_email_btree ON users(email) WHERE email IS NOT NULL;
