const { pool } = require('../config/database');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');

const saveFcmToken = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const { token, platform } = req.body;

  if (!token || typeof token !== 'string' || token.length < 10) {
    return res.status(400).json({ success: false, message: 'Invalid FCM token' });
  }

  await pool.query(
    `INSERT INTO fcm_tokens (user_id, token, platform, updated_at)
     VALUES ($1, $2, $3, NOW())
     ON CONFLICT (token) DO UPDATE SET user_id = $1, platform = $3, updated_at = NOW()`,
    [userId, token, platform || 'android']
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

module.exports = { saveFcmToken, deleteFcmToken };
