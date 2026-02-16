-- Schedule rate_ride notifications 1 minute after booking is confirmed
-- Job runs every minute and sends notifications for rows where send_after <= now()

CREATE TABLE IF NOT EXISTS pending_rate_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  passenger_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  send_after TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pending_rate_send_after ON pending_rate_notifications(send_after);
COMMENT ON TABLE pending_rate_notifications IS 'Rate-your-ride notifications sent 1 min after booking confirm';
