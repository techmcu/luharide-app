-- 022_union_schedules.sql
-- Simple schedule table for union-managed rides (for posters, not live bookings)

CREATE TABLE IF NOT EXISTS union_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  union_id UUID NOT NULL REFERENCES unions(id) ON DELETE CASCADE,
  union_driver_id UUID NOT NULL REFERENCES union_drivers(id) ON DELETE CASCADE,
  from_location VARCHAR(100) NOT NULL,
  to_location VARCHAR(100) NOT NULL,
  departure_time TIMESTAMPTZ NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled', 'cancelled', 'completed')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_union_schedules_union_id
  ON union_schedules(union_id);

CREATE INDEX IF NOT EXISTS idx_union_schedules_departure_time
  ON union_schedules(departure_time);

