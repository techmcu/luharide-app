-- Phase 4: Admin-triggered KYC re-verification + single-use re-upload windows
-- - Drivers (independent): admin can revoke verified status + allow re-upload
-- - Unions: admin can request union doc re-verify; union admin can update docs only when allowed

BEGIN;

-- Users: independent driver KYC re-upload window control
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS driver_kyc_reupload_allowed BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS driver_kyc_reupload_granted_on DATE,
  ADD COLUMN IF NOT EXISTS driver_kyc_reupload_deadline TIMESTAMPTZ;

-- Unions: document verification status + re-upload window control
ALTER TABLE unions
  ADD COLUMN IF NOT EXISTS documents_status TEXT,
  ADD COLUMN IF NOT EXISTS documents_reupload_allowed BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS documents_reupload_granted_on DATE,
  ADD COLUMN IF NOT EXISTS documents_reupload_deadline TIMESTAMPTZ;

-- Backfill: initial union documents_status mirrors union status.
UPDATE unions
SET documents_status = status
WHERE documents_status IS NULL;

-- Normalize any unexpected values.
UPDATE unions
SET documents_status = 'pending'
WHERE documents_status IS NULL OR documents_status NOT IN ('pending', 'approved', 'rejected', 'needs_reverify');

COMMIT;

