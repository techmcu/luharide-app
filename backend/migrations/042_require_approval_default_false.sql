-- Change require_approval default from true to false (auto-approve by default)
ALTER TABLE trips ALTER COLUMN require_approval SET DEFAULT false;
