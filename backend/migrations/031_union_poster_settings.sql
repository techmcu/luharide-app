-- Union poster settings for lightweight customization.
-- Keeps data in unions table (single-row read, no extra join) for low server load.

ALTER TABLE unions
  ADD COLUMN IF NOT EXISTS poster_custom_text VARCHAR(120),
  ADD COLUMN IF NOT EXISTS poster_custom_text_position VARCHAR(10),
  ADD COLUMN IF NOT EXISTS poster_layout_type VARCHAR(20);

ALTER TABLE unions
  DROP CONSTRAINT IF EXISTS unions_poster_custom_text_position_check;

ALTER TABLE unions
  ADD CONSTRAINT unions_poster_custom_text_position_check
  CHECK (
    poster_custom_text_position IS NULL OR
    poster_custom_text_position IN ('top', 'bottom', 'left', 'right')
  );

ALTER TABLE unions
  DROP CONSTRAINT IF EXISTS unions_poster_layout_type_check;

ALTER TABLE unions
  ADD CONSTRAINT unions_poster_layout_type_check
  CHECK (
    poster_layout_type IS NULL OR
    poster_layout_type IN ('classic', 'compact')
  );

COMMENT ON COLUMN unions.poster_custom_text IS 'Optional small text on poster (name/phone/short note).';
COMMENT ON COLUMN unions.poster_custom_text_position IS 'Position for small text: top/bottom/left/right.';
COMMENT ON COLUMN unions.poster_layout_type IS 'Poster template type: classic/compact.';
