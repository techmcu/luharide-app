const admin = require('firebase-admin');
const { pool } = require('../config/database');
const logger = require('../config/logger');

let _initialized = false;

function initFirebaseAdmin() {
  if (_initialized) return;
  _initialized = true;

  const credPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (credPath) {
    const serviceAccount = require(credPath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } else if (process.env.FIREBASE_PROJECT_ID) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID,
    });
  } else {
    logger.warn('Firebase Admin not configured — push notifications disabled. Set FIREBASE_SERVICE_ACCOUNT_PATH in .env');
    return;
  }
  logger.info('Firebase Admin initialized for push notifications');
}

async function sendPushToUser(userId, title, body, data = {}) {
  if (!_initialized || !admin.apps.length) {
    logger.warn({ msg: 'FCM skip: Firebase Admin not initialized', userId });
    return;
  }

  // DISTINCT: a user may have the same token stored more than once (rotation /
  // reinstall races). Without it the same device receives duplicate pushes.
  // Kept in parity with sendPushToMultipleUsers below.
  const result = await pool.query(
    'SELECT DISTINCT token FROM fcm_tokens WHERE user_id = $1',
    [userId]
  );
  if (result.rows.length === 0) {
    logger.info({ msg: 'FCM skip: no tokens for user', userId });
    return;
  }

  const tokens = result.rows.map((r) => r.token);
  const staleTokens = [];
  logger.info({ msg: 'FCM sending', userId, tokenCount: tokens.length, title });

  for (const token of tokens) {
    try {
      const msgId = await admin.messaging().send({
        token,
        notification: { title, body },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)])
        ),
        android: {
          priority: 'high',
          notification: { channelId: 'luharide_default' },
        },
      });
      logger.info({ msg: 'FCM sent OK', userId, msgId });
    } catch (err) {
      if (
        err.code === 'messaging/registration-token-not-registered' ||
        err.code === 'messaging/invalid-registration-token'
      ) {
        staleTokens.push(token);
        logger.warn({ msg: 'FCM stale token removed', userId, code: err.code });
      } else {
        logger.warn({ msg: 'FCM send failed', userId, code: err.code, error: err.message });
      }
    }
  }

  if (staleTokens.length > 0) {
    await pool.query(
      'DELETE FROM fcm_tokens WHERE token = ANY($1::text[])',
      [staleTokens]
    );
  }
}

async function sendPushToMultipleUsers(userIds, title, body, data = {}) {
  if (!_initialized || !admin.apps.length || !userIds.length) return;

  const result = await pool.query(
    'SELECT DISTINCT token FROM fcm_tokens WHERE user_id = ANY($1::uuid[])',
    [userIds]
  );
  if (result.rows.length === 0) return;

  const tokens = result.rows.map((r) => r.token);
  const staleTokens = [];
  const dataStrings = Object.fromEntries(
    Object.entries(data).map(([k, v]) => [k, String(v)])
  );

  const BATCH_SIZE = 500;
  for (let i = 0; i < tokens.length; i += BATCH_SIZE) {
    const batch = tokens.slice(i, i + BATCH_SIZE);
    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: batch,
        notification: { title, body },
        data: dataStrings,
        android: {
          priority: 'high',
          notification: { channelId: 'luharide_default' },
        },
      });
      response.responses.forEach((resp, idx) => {
        if (!resp.success && resp.error) {
          const code = resp.error.code;
          if (
            code === 'messaging/registration-token-not-registered' ||
            code === 'messaging/invalid-registration-token'
          ) {
            staleTokens.push(batch[idx]);
          }
        }
      });
    } catch (err) {
      logger.warn({ msg: 'FCM multicast batch failed', error: err.message, batchSize: batch.length });
    }
  }

  if (staleTokens.length > 0) {
    await pool.query(
      'DELETE FROM fcm_tokens WHERE token = ANY($1::text[])',
      [staleTokens]
    );
  }
}

module.exports = {
  initFirebaseAdmin,
  sendPushToUser,
  sendPushToMultipleUsers,
};
