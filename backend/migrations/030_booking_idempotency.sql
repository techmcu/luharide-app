-- Migration 030: Booking idempotency (duplicate submit / retry same request)
-- Hostinger KVM-friendly: one extra column + index, no new services.

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS idempotency_key VARCHAR(128);

COMMENT ON COLUMN bookings.idempotency_key IS 'Client-supplied key (e.g. Idempotency-Key header); duplicate POST with same key returns same booking.';

-- One idempotency key per passenger (retry safe)
CREATE UNIQUE INDEX IF NOT EXISTS idx_bookings_passenger_idempotency
  ON bookings(passenger_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL AND length(trim(idempotency_key)) > 0;
