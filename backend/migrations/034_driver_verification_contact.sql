-- Driver KYC: contact details collected at verification (independent drivers)
ALTER TABLE driver_verification_requests
  ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(20),
  ADD COLUMN IF NOT EXISTS contact_email VARCHAR(150);

COMMENT ON COLUMN driver_verification_requests.contact_phone IS 'Driver contact mobile at verification time';
COMMENT ON COLUMN driver_verification_requests.contact_email IS 'Driver contact email at verification time';
