-- 020_union_drivers.sql
-- Basic union_drivers table for union-managed driver list

CREATE TABLE IF NOT EXISTS union_drivers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  union_id UUID NOT NULL REFERENCES unions(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  vehicle_number VARCHAR(32) NOT NULL,
  phone VARCHAR(20),
  whatsapp_number VARCHAR(20),
  profile_image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_union_drivers_union_id
  ON union_drivers(union_id);

