-- Add poster_header column to unions table.
-- This stores a one-time custom top line (e.g. a blessing or deity name)
-- that the union admin sets once and appears on every generated poster.

ALTER TABLE unions
  ADD COLUMN IF NOT EXISTS poster_header VARCHAR(200);
