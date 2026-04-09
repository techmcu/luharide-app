-- Speed admin list of unions awaiting document review (partial index, low write overhead).
CREATE INDEX IF NOT EXISTS idx_unions_approved_docs_pending
  ON unions (updated_at DESC, created_at DESC)
  WHERE status = 'approved' AND documents_status = 'pending';
