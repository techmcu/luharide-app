-- Migration: Driver Verification System
-- Created: 2026-02-12
-- Description: Add driver verification flow - users become drivers via profile after admin approval

-- ============================================
-- 1. Add driver_verification_status to users
-- ============================================
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'users' AND column_name = 'driver_verification_status'
  ) THEN
    ALTER TABLE users ADD COLUMN driver_verification_status VARCHAR(20) 
      DEFAULT 'none' CHECK (driver_verification_status IN ('none', 'pending', 'approved', 'rejected'));
  END IF;
END $$;

-- Set existing drivers as approved
UPDATE users SET driver_verification_status = 'approved' WHERE role = 'driver' AND driver_verification_status = 'none';

-- ============================================
-- 2. Driver Verification Requests Table
-- ============================================
CREATE TABLE IF NOT EXISTS driver_verification_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  driving_license_number VARCHAR(50),
  driving_license_url TEXT,
  vehicle_registration VARCHAR(20),
  vehicle_type VARCHAR(50),
  vehicle_model VARCHAR(100),
  vehicle_capacity INTEGER,
  rc_document_url TEXT,
  permit_document_url TEXT,
  insurance_document_url TEXT,
  aadhaar_document_url TEXT,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  rejection_reason TEXT,
  reviewed_by UUID REFERENCES users(id),
  reviewed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id)
);

CREATE INDEX idx_driver_verification_user ON driver_verification_requests(user_id);
CREATE INDEX idx_driver_verification_status ON driver_verification_requests(status);

-- Trigger for updated_at
CREATE TRIGGER update_driver_verification_updated_at 
  BEFORE UPDATE ON driver_verification_requests
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE driver_verification_requests IS 'Driver document submission and approval workflow';
