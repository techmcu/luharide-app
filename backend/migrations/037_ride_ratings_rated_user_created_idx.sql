-- Speed up “latest N reviews per user” (ORDER BY created_at DESC, LIMIT) and summary MAX(created_at).
CREATE INDEX IF NOT EXISTS idx_ride_ratings_rated_user_created
  ON ride_ratings (rated_user_id, created_at DESC);
