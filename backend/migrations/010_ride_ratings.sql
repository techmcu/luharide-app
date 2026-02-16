-- Ride ratings: passenger and driver can rate each other after booking is accepted
-- Comment max 20 words enforced in API

-- Ensure notifications has data column (for rate_ride booking_id)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'notifications' AND column_name = 'data'
  ) THEN
    ALTER TABLE notifications ADD COLUMN data JSONB;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS ride_ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rated_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  from_role VARCHAR(20) NOT NULL CHECK (from_role IN ('passenger', 'driver')),
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(booking_id, from_role)
);

CREATE INDEX idx_ride_ratings_rated_user ON ride_ratings(rated_user_id);
CREATE INDEX idx_ride_ratings_booking ON ride_ratings(booking_id);

COMMENT ON TABLE ride_ratings IS 'Passenger and driver rate each other after ride (comment max 20 words in API)';
