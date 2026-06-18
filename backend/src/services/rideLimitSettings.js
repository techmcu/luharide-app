/**
 * Independent-driver ride limits (admin-controlled via the `settings` table).
 *
 * Read on the ride-creation path, so it is cached in-process with a short TTL.
 * This keeps the hot path off the DB without needing Redis (a 2-integer value
 * that changes only when an admin edits it). The cache:
 *   - serves the last good value if the DB read fails (never throws),
 *   - falls back to safe defaults when nothing is cached yet,
 *   - converges across processes within TTL_MS of an admin change.
 *
 * Semantics (both limits are whole numbers in [0, 100]):
 *   - daily / weekly  : max independent rides a driver may CREATE in that window.
 *   - 0               : kill switch — independent ride creation is fully blocked.
 *
 * Defaults preserve historic behaviour: 4/day, and a weekly cap high enough that
 * it never binds until an admin lowers it.
 */
const { queryRead } = require('../config/database');
const logger = require('../config/logger');

const DAILY_KEY = 'independent_daily_ride_limit';
const WEEKLY_KEY = 'independent_weekly_ride_limit';

const DEFAULTS = Object.freeze({ daily: 4, weekly: 28 });
const MIN_LIMIT = 0;
const MAX_LIMIT = 100;
const TTL_MS = 60 * 1000;

let _cache = null; // { daily, weekly }
let _cacheAt = 0;

/**
 * Parse a stored setting into a valid whole-number limit, or return `fallback`.
 * Rejects floats ("3.5"), text, emojis, negatives, blanks and out-of-range —
 * defence in depth even though the admin write path also validates.
 */
function parseLimitValue(raw, fallback) {
  if (raw === null || raw === undefined) return fallback;
  const s = String(raw).trim();
  if (!/^\d+$/.test(s)) return fallback; // digits only — no '.', '-', emoji, text
  const n = Number(s);
  if (!Number.isInteger(n) || n < MIN_LIMIT || n > MAX_LIMIT) return fallback;
  return n;
}

async function getIndependentRideLimits() {
  const now = Date.now();
  if (_cache && now - _cacheAt < TTL_MS) return _cache;

  try {
    const res = await queryRead(
      `SELECT key, value FROM settings WHERE key IN ($1, $2)`,
      [DAILY_KEY, WEEKLY_KEY]
    );
    const map = {};
    for (const row of res.rows) map[row.key] = row.value;
    _cache = {
      daily: parseLimitValue(map[DAILY_KEY], DEFAULTS.daily),
      weekly: parseLimitValue(map[WEEKLY_KEY], DEFAULTS.weekly),
    };
    _cacheAt = now;
  } catch (e) {
    logger.warn(`[rideLimitSettings] read failed, serving ${_cache ? 'stale cache' : 'defaults'}: ${e.message}`);
    if (_cache) return _cache;
    _cache = { ...DEFAULTS };
    _cacheAt = now;
  }
  return _cache;
}

function invalidateRideLimitsCache() {
  _cache = null;
  _cacheAt = 0;
}

module.exports = {
  getIndependentRideLimits,
  invalidateRideLimitsCache,
  parseLimitValue,
  DAILY_KEY,
  WEEKLY_KEY,
  DEFAULTS,
  MIN_LIMIT,
  MAX_LIMIT,
};
