-- Prefer storing SHA-256 hex of refresh JWT instead of plaintext (reduces DB leak impact).
-- Legacy rows keep `token` set; new sessions use `token_hash` with `token` NULL.

ALTER TABLE refresh_tokens ALTER COLUMN token DROP NOT NULL;

ALTER TABLE refresh_tokens ADD COLUMN IF NOT EXISTS token_hash VARCHAR(64);

COMMENT ON COLUMN refresh_tokens.token_hash IS 'SHA-256 hex of refresh JWT; new rows use this only.';

CREATE INDEX IF NOT EXISTS idx_refresh_token_hash ON refresh_tokens(token_hash)
  WHERE token_hash IS NOT NULL;

-- At most one non-revoked session per hash (new token storage path).
CREATE UNIQUE INDEX IF NOT EXISTS idx_refresh_tokens_hash_active
  ON refresh_tokens(token_hash)
  WHERE token_hash IS NOT NULL AND is_revoked = FALSE;
