-- Optional text: stand/share location details for union (stored trimmed, max length enforced in API)
ALTER TABLE unions ADD COLUMN IF NOT EXISTS union_share_notes TEXT;

COMMENT ON COLUMN unions.union_share_notes IS 'Optional: union stand / share point details for verification';
