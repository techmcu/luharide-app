-- Admin-created rides: track who created, poster contact, extra notes
ALTER TABLE trips ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS poster_driver_name VARCHAR(100);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS poster_contact VARCHAR(15);
ALTER TABLE trips ADD COLUMN IF NOT EXISTS admin_notes TEXT;
CREATE INDEX IF NOT EXISTS idx_trips_created_by ON trips(created_by);
CREATE INDEX IF NOT EXISTS idx_trips_created_source ON trips(created_source);
