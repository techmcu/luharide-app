const { pool } = require('../config/database');
const { generateTokenPair } = require('../services/tokenService');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { OAuth2Client } = require('google-auth-library');

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
if (!GOOGLE_CLIENT_ID && process.env.NODE_ENV === 'production') {
  logger.error('GOOGLE_CLIENT_ID env var is required in production');
}

const googleClient = GOOGLE_CLIENT_ID ? new OAuth2Client(GOOGLE_CLIENT_ID) : null;

let _firebaseAdmin = null;
function getFirebaseAuth() {
  if (_firebaseAdmin !== null) return _firebaseAdmin;
  try {
    const admin = require('firebase-admin');
    if (admin.apps.length > 0) {
      _firebaseAdmin = admin.auth();
      return _firebaseAdmin;
    }
  } catch (_) { /* not available */ }
  _firebaseAdmin = false;
  return false;
}

function buildUserResponse(user, isNewUser, isAppAdmin) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    isVerified: user.is_verified ?? true,
    isActive: user.is_active ?? true,
    driverVerificationStatus: user.driver_verification_status || 'none',
    driverKycReuploadAllowed: user.driver_kyc_reupload_allowed === true,
    driverCode: user.driver_code || null,
    has_password: isNewUser ? false : !!user.password_hash,
    isAppAdmin
  };
}

/**
 * Google Sign-In
 * POST /api/simple-auth/google
 */
const googleSignIn = asyncHandler(async (req, res) => {
  const { idToken } = req.body;

  if (!idToken) {
    throw ApiError.badRequest('Google ID token is required');
  }

  if (!googleClient) {
    throw ApiError.serviceUnavailable('Google Sign-In is not configured');
  }

  let payload;
  try {
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: GOOGLE_CLIENT_ID,
    });
    payload = ticket.getPayload();
  } catch (err) {
    logger.warn(`Google token verification failed: ${err.message}`);
    await logFailedLogin(null, 'google', req, 'invalid_token');
    throw ApiError.unauthorized('Invalid Google token');
  }

  const email = (payload.email || '').toLowerCase().trim();
  const name = payload.name || payload.given_name || 'User';
  const googleId = payload.sub;

  if (!email) {
    throw ApiError.badRequest('Google account has no email');
  }

  if (!payload.email_verified) {
    throw ApiError.badRequest('Google email not verified');
  }

  const adminEmail = process.env.ADMIN_EMAIL ? process.env.ADMIN_EMAIL.toLowerCase().trim() : null;
  const isAppAdmin = adminEmail && email === adminEmail;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    let existingUser;
    try {
      existingUser = await client.query(
        `SELECT id, name, phone, email, role, is_verified, is_active, driver_verification_status,
                driver_kyc_reupload_allowed, driver_code, password_hash, google_id,
                profile_image_url, whatsapp_number, failed_login_attempts, locked_until
         FROM users WHERE email = $1 FOR UPDATE`,
        [email]
      );
    } catch (err) {
      if (err.code === '42703') {
        existingUser = await client.query(
          `SELECT id, name, phone, email, role, is_verified, is_active, driver_verification_status,
                  driver_kyc_reupload_allowed, driver_code, password_hash, google_id,
                  profile_image_url, whatsapp_number
           FROM users WHERE email = $1 FOR UPDATE`,
          [email]
        );
      } else { throw err; }
    }

    let user;
    let isNewUser = false;

    if (existingUser.rows.length > 0) {
      user = existingUser.rows[0];

      if (!user.is_active) {
        await client.query('COMMIT');
        await logFailedLogin(user.id, 'google', req, 'account_deactivated');
        throw ApiError.forbidden('Your account has been suspended. Please contact support for assistance.');
      }

      if (user.locked_until && new Date(user.locked_until) > new Date()) {
        const minsLeft = Math.ceil((new Date(user.locked_until) - new Date()) / 60000);
        await client.query('COMMIT');
        throw ApiError.tooManyRequests(`Account temporarily locked. Try again in ${minsLeft} minute(s).`);
      }

      if (!user.google_id) {
        try {
          await client.query(
            `UPDATE users SET google_id = $1, failed_login_attempts = 0, locked_until = NULL, last_login = CURRENT_TIMESTAMP WHERE id = $2`,
            [googleId, user.id]
          );
        } catch (e) {
          if (e.code === '42703') {
            await client.query(`UPDATE users SET google_id = $1, last_login = CURRENT_TIMESTAMP WHERE id = $2`, [googleId, user.id]);
          } else { throw e; }
        }
      } else {
        try {
          await client.query(
            `UPDATE users SET failed_login_attempts = 0, locked_until = NULL, last_login = CURRENT_TIMESTAMP WHERE id = $1`,
            [user.id]
          );
        } catch (e) {
          if (e.code === '42703') {
            await client.query(`UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1`, [user.id]);
          } else { throw e; }
        }
      }
    } else {
      isNewUser = true;
      const effectiveRole = isAppAdmin ? 'union_admin' : 'passenger';

      const result = await client.query(
        `INSERT INTO users (name, email, google_id, role, is_verified, is_active)
         VALUES ($1, $2, $3, $4, TRUE, TRUE)
         RETURNING id, name, phone, email, role, is_verified, is_active, driver_verification_status,
                   driver_kyc_reupload_allowed, driver_code, profile_image_url, whatsapp_number`,
        [name, email, googleId, effectiveRole]
      );

      user = result.rows[0];
      user.password_hash = null;
      logger.info(`New Google user created: ${user.id} - ${email}`);
    }

    await client.query('COMMIT');

    const tokens = await generateTokenPair(
      user.id,
      user.role,
      { userAgent: req.headers['user-agent'] },
      req.ip
    );

    await pool.query(
      `INSERT INTO login_history (user_id, login_type, device_info, ip_address, user_agent, status)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [user.id, 'google', JSON.stringify({ googleId }), req.ip, req.headers['user-agent'], 'success']
    );

    logger.info(`Google sign-in: ${user.id} - ${email} (${isNewUser ? 'new' : 'existing'})`);

    const responseData = {
      user: buildUserResponse(user, isNewUser, isAppAdmin),
      tokens,
      isNewUser
    };

    if (isNewUser) {
      ApiResponse.created(responseData, 'Google sign-in successful').send(res);
    } else {
      ApiResponse.success(responseData, 'Google sign-in successful').send(res);
    }
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
});

/**
 * Firebase Email Link Sign-In
 * POST /api/simple-auth/firebase-email
 */
const firebaseEmailSignIn = asyncHandler(async (req, res) => {
  const { idToken, name } = req.body;

  if (!idToken) {
    throw ApiError.badRequest('Firebase ID token is required');
  }

  const fbAuth = getFirebaseAuth();
  let email, displayName, firebaseUid;

  if (fbAuth) {
    try {
      const decoded = await fbAuth.verifyIdToken(idToken);
      email = (decoded.email || '').toLowerCase().trim();
      displayName = name || decoded.name || 'User';
      firebaseUid = decoded.uid;
    } catch (err) {
      logger.warn(`Firebase token verification failed: ${err.message}`);
      await logFailedLogin(null, 'firebase_email', req, 'invalid_token');
      throw ApiError.unauthorized('Invalid Firebase token');
    }
  } else {
    const firebaseProjectId = (process.env.FIREBASE_PROJECT_ID || '').trim();
    if (!firebaseProjectId) {
      logger.error('Firebase Admin not initialized and FIREBASE_PROJECT_ID not set — cannot verify token');
      throw ApiError.serviceUnavailable('Firebase authentication is not configured');
    }

    logger.warn('Firebase Admin not initialized — falling back to tokeninfo endpoint for email sign-in');
    const verifyUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
    const googleRes = await fetch(verifyUrl);
    if (!googleRes.ok) {
      await logFailedLogin(null, 'firebase_email', req, 'invalid_token');
      throw ApiError.unauthorized('Invalid Firebase token');
    }
    const payload = await googleRes.json();

    if (payload.aud !== firebaseProjectId) {
      logger.warn(`Firebase token audience mismatch: expected ${firebaseProjectId}, got ${payload.aud}`);
      await logFailedLogin(null, 'firebase_email', req, 'audience_mismatch');
      throw ApiError.unauthorized('Invalid Firebase token');
    }

    email = (payload.email || '').toLowerCase().trim();
    displayName = name || payload.name || 'User';
    firebaseUid = payload.sub;
  }

  if (!email) {
    throw ApiError.badRequest('No email in Firebase token');
  }

  const adminEmail = process.env.ADMIN_EMAIL ? process.env.ADMIN_EMAIL.toLowerCase().trim() : null;
  const isAppAdmin = adminEmail && email === adminEmail;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    let existingUser;
    try {
      existingUser = await client.query(
        `SELECT id, name, phone, email, role, is_verified, is_active, driver_verification_status,
                driver_kyc_reupload_allowed, driver_code, password_hash, firebase_uid,
                profile_image_url, whatsapp_number, failed_login_attempts, locked_until
         FROM users WHERE email = $1 FOR UPDATE`,
        [email]
      );
    } catch (err) {
      if (err.code === '42703') {
        existingUser = await client.query(
          `SELECT id, name, phone, email, role, is_verified, is_active, driver_verification_status,
                  driver_kyc_reupload_allowed, driver_code, password_hash, firebase_uid,
                  profile_image_url, whatsapp_number
           FROM users WHERE email = $1 FOR UPDATE`,
          [email]
        );
      } else { throw err; }
    }

    let user;
    let isNewUser = false;

    if (existingUser.rows.length > 0) {
      user = existingUser.rows[0];

      if (!user.is_active) {
        await client.query('COMMIT');
        await logFailedLogin(user.id, 'firebase_email', req, 'account_deactivated');
        throw ApiError.forbidden('Your account has been suspended. Please contact support for assistance.');
      }

      if (user.locked_until && new Date(user.locked_until) > new Date()) {
        const minsLeft = Math.ceil((new Date(user.locked_until) - new Date()) / 60000);
        await client.query('COMMIT');
        throw ApiError.tooManyRequests(`Account temporarily locked. Try again in ${minsLeft} minute(s).`);
      }

      if (!user.firebase_uid) {
        try {
          await client.query(
            `UPDATE users SET firebase_uid = $1, failed_login_attempts = 0, locked_until = NULL, last_login = CURRENT_TIMESTAMP WHERE id = $2`,
            [firebaseUid, user.id]
          );
        } catch (e) {
          if (e.code === '42703') {
            await client.query(`UPDATE users SET firebase_uid = $1, last_login = CURRENT_TIMESTAMP WHERE id = $2`, [firebaseUid, user.id]);
          } else { throw e; }
        }
      } else {
        try {
          await client.query(
            `UPDATE users SET failed_login_attempts = 0, locked_until = NULL, last_login = CURRENT_TIMESTAMP WHERE id = $1`,
            [user.id]
          );
        } catch (e) {
          if (e.code === '42703') {
            await client.query(`UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1`, [user.id]);
          } else { throw e; }
        }
      }
    } else {
      isNewUser = true;
      const effectiveRole = isAppAdmin ? 'union_admin' : 'passenger';

      const result = await client.query(
        `INSERT INTO users (name, email, firebase_uid, role, is_verified, is_active)
         VALUES ($1, $2, $3, $4, TRUE, TRUE)
         RETURNING id, name, phone, email, role, is_verified, is_active, driver_verification_status,
                   driver_kyc_reupload_allowed, driver_code, profile_image_url, whatsapp_number`,
        [displayName, email, firebaseUid, effectiveRole]
      );

      user = result.rows[0];
      user.password_hash = null;
      logger.info(`New Firebase email user created: ${user.id} - ${email}`);
    }

    await client.query('COMMIT');

    const tokens = await generateTokenPair(
      user.id,
      user.role,
      { userAgent: req.headers['user-agent'] },
      req.ip
    );

    await pool.query(
      `INSERT INTO login_history (user_id, login_type, device_info, ip_address, user_agent, status)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [user.id, 'firebase_email', JSON.stringify({ firebaseUid }), req.ip, req.headers['user-agent'], 'success']
    );

    const responseData = {
      user: buildUserResponse(user, isNewUser, isAppAdmin),
      tokens,
      isNewUser
    };

    if (isNewUser) {
      ApiResponse.created(responseData, 'Email link sign-in successful').send(res);
    } else {
      ApiResponse.success(responseData, 'Email link sign-in successful').send(res);
    }
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
});

async function logFailedLogin(userId, loginType, req, reason) {
  try {
    await pool.query(
      `INSERT INTO login_history (user_id, login_type, device_info, ip_address, user_agent, status, failure_reason)
       VALUES ($1, $2, $3, $4, $5, 'failed', $6)`,
      [userId, loginType, JSON.stringify({}), req.ip, req.headers['user-agent'], reason]
    );
  } catch (err) {
    logger.warn(`Failed to log login attempt: ${err.message}`);
  }
}

module.exports = {
  googleSignIn,
  firebaseEmailSignIn
};
