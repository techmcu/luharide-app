/**
 * Normalize client-provided KYC upload references to a safe API-relative path.
 * Accepts /uploads/..., uploads/... (missing leading slash), or full http(s) URLs
 * whose pathname starts with /uploads/.
 */
function sanitizeKycUploadUrl(raw) {
  if (raw == null || raw === '') return null;
  let s = String(raw).trim();
  if (s.length > 2048) return null;
  if (/^https?:\/\//i.test(s)) {
    try {
      s = new URL(s).pathname || '';
    } catch {
      return null;
    }
  }
  if (!s.startsWith('/')) {
    if (s.startsWith('uploads/')) s = `/${s}`;
    else return null;
  }
  if (!s.startsWith('/uploads/')) return null;
  if (s.includes('..')) return null;
  return s;
}

module.exports = { sanitizeKycUploadUrl };
