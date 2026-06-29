const { pool } = require('../config/database');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');

/** Accept only languages the app actually supports; everything else → null (no-op). */
function normalizeLanguage(value) {
  return value === 'hi' || value === 'en' ? value : null;
}

const saveFcmToken = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const { token, platform, language } = req.body;

  if (!token || typeof token !== 'string' || token.length < 10) {
    return res.status(400).json({ success: false, message: 'Invalid FCM token' });
  }

  // The app sends its current language alongside the token on every login, so the
  // server can render notifications in the right language. Best-effort.
  const lang = normalizeLanguage(language);
  if (lang) {
    try {
      await pool.query('UPDATE users SET preferred_language = $1 WHERE id = $2', [lang, userId]);
    } catch (_) { /* column may not exist pre-068; ignore */ }
  }

  await pool.query(
    `INSERT INTO fcm_tokens (user_id, token, platform, updated_at)
     VALUES ($1, $2, $3, NOW())
     ON CONFLICT (token) DO UPDATE SET user_id = $1, platform = $3, updated_at = NOW()`,
    [userId, token, platform || 'android']
  );

  // Keep only this user's 3 most-recent tokens. App reinstalls / FCM token
  // rotation leave dead rows behind; those make the same phone receive the
  // notification multiple times. Pruning bounds it while still supporting a few
  // real devices per user.
  await pool.query(
    `DELETE FROM fcm_tokens
     WHERE user_id = $1
       AND token NOT IN (
         SELECT token FROM fcm_tokens
         WHERE user_id = $1
         ORDER BY updated_at DESC
         LIMIT 3
       )`,
    [userId]
  );

  ApiResponse.success(null, 'FCM token saved').send(res);
});

const deleteFcmToken = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const { token } = req.body;

  if (token) {
    await pool.query(
      'DELETE FROM fcm_tokens WHERE user_id = $1 AND token = $2',
      [userId, token]
    );
  } else {
    await pool.query('DELETE FROM fcm_tokens WHERE user_id = $1', [userId]);
  }

  ApiResponse.success(null, 'FCM token removed').send(res);
});

/**
 * Update only the user's notification language — used when the user toggles
 * language in-app (no token involved). Web clients use this too. Idempotent.
 */
const setLanguage = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const lang = normalizeLanguage(req.body.language);
  if (!lang) {
    return res.status(400).json({ success: false, message: 'Invalid language' });
  }
  try {
    await pool.query('UPDATE users SET preferred_language = $1 WHERE id = $2', [lang, userId]);
  } catch (_) { /* column may not exist pre-068; ignore */ }
  ApiResponse.success(null, 'Language preference saved').send(res);
});

module.exports = { saveFcmToken, deleteFcmToken, setLanguage };
