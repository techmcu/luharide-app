const USER_TTL_MS = 60_000;
const MAX_ENTRIES = 10_000;

const _cache = new Map();

function get(userId) {
  const entry = _cache.get(userId);
  if (!entry) return null;
  if (Date.now() > entry.expiresAt) {
    _cache.delete(userId);
    return null;
  }
  return entry.data;
}

function set(userId, data) {
  if (_cache.size >= MAX_ENTRIES) {
    const first = _cache.keys().next().value;
    _cache.delete(first);
  }
  _cache.set(userId, { data, expiresAt: Date.now() + USER_TTL_MS });
}

function invalidate(userId) {
  _cache.delete(userId);
}

function clear() {
  _cache.clear();
}

module.exports = { get, set, invalidate, clear };
