const { pool } = require('../config/database');
const { generateTokenPair } = require('../services/tokenService');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { OAuth2Client } = require('google-auth-library');

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '698013485373-fkd9oupqd5srtgrnle155t4h4elkvc9o.apps.googleusercontent.com';
const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);

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

/**
 * Google Sign-In
 * POST /api/simple-auth/google
 */
const googleSignIn = asyncHandler(async (req, res) => {
  const { idToken, role = 'passenger' } = req.body;

  if (!idToken) {
    throw ApiError.badRequest('Google ID token is required');
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
  const effectiveRole = isAppAdmin ? 'union_admin' : role;

  const existingUser = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [email]
  );

  let user;
  let isNewUser = false;

  if (existingUser.rows.length > 0) {
    user = existingUser.rows[0];

    if (!user.is_active) {
      throw ApiError.unauthorized('Invalid credentials');
    }

    await pool.query(
      `UPDATE users SET google_id = COALESCE(google_id, $1), last_login = CURRENT_TIMESTAMP WHERE id = $2`,
      [googleId, user.id]
    );
  } else {
    isNewUser = true;

    const result = await pool.query(
      `INSERT INTO users (name, email, google_id, role, is_verified, is_active)
       VALUES ($1, $2, $3, $4, TRUE, TRUE)
       RETURNING id, name, email, role, is_verified, is_active, driver_verification_status, driver_kyc_reupload_allowed, driver_code, created_at`,
      [name, email, googleId, effectiveRole]
    );

    user = result.rows[0];
    logger.info(`New Google user created: ${user.id} - ${email}`);
  }

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
    user: {
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
    },
    tokens,
    isNewUser
  };

  if (isNewUser) {
    ApiResponse.created(responseData, 'Google sign-in successful').send(res);
  } else {
    ApiResponse.success(responseData, 'Google sign-in successful').send(res);
  }
});

/**
 * Firebase Email Link Sign-In
 * POST /api/simple-auth/firebase-email
 */
const firebaseEmailSignIn = asyncHandler(async (req, res) => {
  const { idToken, name, role = 'passenger' } = req.body;

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
      throw ApiError.unauthorized('Invalid Firebase token');
    }
  } else {
    logger.warn('Firebase Admin not initialized — falling back to tokeninfo endpoint for email sign-in');
    const verifyUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
    const googleRes = await fetch(verifyUrl);
    if (!googleRes.ok) {
      throw ApiError.unauthorized('Invalid Firebase token');
    }
    const payload = await googleRes.json();
    email = (payload.email || '').toLowerCase().trim();
    displayName = name || payload.name || 'User';
    firebaseUid = payload.sub;

    const firebaseProjectId = (process.env.FIREBASE_PROJECT_ID || '').trim();
    if (firebaseProjectId && payload.aud !== firebaseProjectId) {
      throw ApiError.unauthorized('Invalid Firebase token');
    }
  }

  if (!email) {
    throw ApiError.badRequest('No email in Firebase token');
  }

  const adminEmail = process.env.ADMIN_EMAIL ? process.env.ADMIN_EMAIL.toLowerCase().trim() : null;
  const isAppAdmin = adminEmail && email === adminEmail;
  const effectiveRole = isAppAdmin ? 'union_admin' : role;

  const existingUser = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [email]
  );

  let user;
  let isNewUser = false;

  if (existingUser.rows.length > 0) {
    user = existingUser.rows[0];

    if (!user.is_active) {
      throw ApiError.unauthorized('Invalid credentials');
    }

    await pool.query(
      'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1',
      [user.id]
    );
  } else {
    isNewUser = true;

    const result = await pool.query(
      `INSERT INTO users (name, email, firebase_uid, role, is_verified, is_active)
       VALUES ($1, $2, $3, $4, TRUE, TRUE)
       RETURNING id, name, email, role, is_verified, is_active, driver_verification_status, driver_kyc_reupload_allowed, driver_code, created_at`,
      [displayName, email, firebaseUid, effectiveRole]
    );

    user = result.rows[0];
    logger.info(`New Firebase email user created: ${user.id} - ${email}`);
  }

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
    user: {
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
    },
    tokens,
    isNewUser
  };

  if (isNewUser) {
    ApiResponse.created(responseData, 'Email link sign-in successful').send(res);
  } else {
    ApiResponse.success(responseData, 'Email link sign-in successful').send(res);
  }
});

module.exports = {
  googleSignIn,
  firebaseEmailSignIn
};
