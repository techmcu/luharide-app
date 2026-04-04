const path = require('path');

/**
 * Map an API-relative upload URL to an absolute path under backend/uploads/{subdir}.
 * Rejects traversal and nested paths.
 *
 * @param {string} relativeUrl e.g. /uploads/driver-docs/file.jpg
 * @param {'driver-docs'|'union-docs'|'union-raw'|'union-merged'} subdir
 * @returns {string|null}
 */
function resolveVerifiedUploadPath(relativeUrl, subdir) {
  const s = String(relativeUrl || '').trim();
  const prefix = `/uploads/${subdir}/`;
  if (!s.startsWith(prefix)) return null;
  const name = s.slice(prefix.length);
  if (
    !name ||
    name.includes('..') ||
    name.includes('/') ||
    name.includes('\\') ||
    name.length > 512
  ) {
    return null;
  }
  const uploadsRoot = path.join(__dirname, '..', '..', 'uploads', subdir);
  const abs = path.join(uploadsRoot, name);
  const normalizedRoot = path.normalize(uploadsRoot + path.sep);
  const normalizedAbs = path.normalize(abs);
  if (!normalizedAbs.startsWith(normalizedRoot)) return null;
  return normalizedAbs;
}

module.exports = { resolveVerifiedUploadPath };
