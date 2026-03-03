-- 021_union_routes.sql
-- Preset routes (from/to) per union for fast ride creation

CREATE TABLE IF NOT EXISTS union_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  union_id UUID NOT NULL REFERENCES unions(id) ON DELETE CASCADE,
  from_location VARCHAR(100) NOT NULL,
  to_location VARCHAR(100) NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_union_routes_union_id
  ON union_routes(union_id);

