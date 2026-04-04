-- Optional per-trip luggage note for passengers (independent driver create ride).
ALTER TABLE trips ADD COLUMN IF NOT EXISTS luggage_allowance_per_passenger TEXT;

COMMENT ON COLUMN trips.luggage_allowance_per_passenger IS 'Optional: luggage allowance for this ride only (shown to passengers).';
