-- 1. Add estimated_duration_hours to trips (driver-provided travel time)
ALTER TABLE trips ADD COLUMN IF NOT EXISTS estimated_duration_hours NUMERIC(4,1);

-- 2. Unique constraint on pending_rate_notifications to prevent duplicate rating notifications
-- Drop existing duplicates first (keep earliest)
DELETE FROM pending_rate_notifications a
USING pending_rate_notifications b
WHERE a.booking_id = b.booking_id
  AND a.created_at > b.created_at;

CREATE UNIQUE INDEX IF NOT EXISTS uq_pending_rate_booking
  ON pending_rate_notifications (booking_id);

-- 3. Driver abuse flags table — tracks create+cancel abuse for admin/union visibility
CREATE TABLE IF NOT EXISTS driver_abuse_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  flag_type VARCHAR(50) NOT NULL,
  reason TEXT NOT NULL,
  month_window VARCHAR(7) NOT NULL,
  violation_count INT NOT NULL DEFAULT 1,
  blocked_until TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  resolved_at TIMESTAMP WITH TIME ZONE,
  resolved_by UUID REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_driver_abuse_user ON driver_abuse_flags (user_id, flag_type);
CREATE INDEX IF NOT EXISTS idx_driver_abuse_unresolved ON driver_abuse_flags (user_id) WHERE resolved_at IS NULL;

COMMENT ON TABLE driver_abuse_flags IS 'Tracks drivers who abuse create+cancel cycles. Visible to platform admin and union admin for banning.';
