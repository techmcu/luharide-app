/**
 * Shared env parser for rate-limit `max` values (unit-tested).
 */
function parseLimitEnv(name, defaultVal, min, max) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return defaultVal;
  const v = parseInt(String(raw), 10);
  if (!Number.isFinite(v)) return defaultVal;
  return Math.min(max, Math.max(min, v));
}

module.exports = { parseLimitEnv };
