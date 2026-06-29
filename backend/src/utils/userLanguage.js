/**
 * Helpers to read a user's stored notification language (migration 068).
 *
 * Accept any pg querier (the shared `pool` or an in-transaction `client`) so the
 * lifecycle job can read languages inside its existing transaction. Always resolve
 * to a usable code — a missing row or column (pre-068) degrades to the default
 * language rather than throwing, so notifications never break.
 */
const { DEFAULT_LANG } = require('./notificationText');

/** Language for a single user. Never throws. */
async function getUserLang(querier, userId) {
  if (!userId) return DEFAULT_LANG;
  try {
    const r = await querier.query(
      'SELECT preferred_language FROM users WHERE id = $1',
      [userId]
    );
    return r.rows[0]?.preferred_language || DEFAULT_LANG;
  } catch (_) {
    return DEFAULT_LANG; // column may not exist yet on an un-migrated DB
  }
}

/** Map of userId -> language for many users in one query. Never throws. */
async function getUserLangs(querier, userIds) {
  const map = new Map();
  const ids = [...new Set((userIds || []).filter(Boolean))];
  if (ids.length === 0) return map;
  try {
    const r = await querier.query(
      'SELECT id, preferred_language FROM users WHERE id = ANY($1::uuid[])',
      [ids]
    );
    for (const row of r.rows) {
      map.set(row.id, row.preferred_language || DEFAULT_LANG);
    }
  } catch (_) { /* pre-068 DB — callers fall back to DEFAULT_LANG via langOf */ }
  return map;
}

/** Read a language out of a getUserLangs map with a safe default. */
function langOf(map, userId) {
  return map.get(userId) || DEFAULT_LANG;
}

module.exports = { getUserLang, getUserLangs, langOf };
