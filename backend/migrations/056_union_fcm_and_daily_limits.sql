-- Union FCM toggle (per-union)
ALTER TABLE unions ADD COLUMN IF NOT EXISTS fcm_enabled BOOLEAN NOT NULL DEFAULT true;

-- Global FCM setting for union ride notifications
INSERT INTO settings (key, value, description)
VALUES ('fcm_global_union_rides', 'true', 'Global on/off for FCM push when unions create rides')
ON CONFLICT (key) DO NOTHING;

-- Track daily union actions for rate limiting (bulk schedule creation, poster generation)
CREATE TABLE IF NOT EXISTS union_daily_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  union_id UUID NOT NULL REFERENCES unions(id) ON DELETE CASCADE,
  action_type VARCHAR(30) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_union_daily_actions_lookup
  ON union_daily_actions (union_id, action_type, created_at);
