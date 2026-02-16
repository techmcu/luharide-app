-- Passenger cancel booking (cancelled_at, reason), user bio, driver luggage, recent routes
-- UUID/user_id based, enterprise-friendly

-- Bookings: cancellation audit
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE,
  ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- Users: bio (max 20 words enforced in API), driver luggage allowance
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS luggage_allowance_per_passenger VARCHAR(100);

COMMENT ON COLUMN users.bio IS 'User bio, max 20 words (enforced in API)';
COMMENT ON COLUMN users.luggage_allowance_per_passenger IS 'Driver: e.g. 1 bag, 2 bags (shown to passengers)';

-- Recent routes: per user, for quick search (UUID-based)
CREATE TABLE IF NOT EXISTS recent_routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  from_location VARCHAR(200) NOT NULL,
  to_location VARCHAR(200) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recent_routes_user ON recent_routes(user_id);
CREATE INDEX IF NOT EXISTS idx_recent_routes_user_created ON recent_routes(user_id, created_at DESC);

COMMENT ON TABLE recent_routes IS 'Last N route searches per user for quick search';
