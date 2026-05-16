const { pool } = require('../config/database');
const { generateTokenPair } = require('../services/tokenService');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

/**
 * Google / Firebase Sign-In
 * POST /api/simple-auth/google
 *
 * The mobile app sends the Google ID token (from Google Sign-In).
 * We verify it using Google's tokeninfo endpoint, extract email/name,
 * then find-or-create the user in our DB and issue our own JWT tokens.
 */
const googleSignIn = asyncHandler(async (req, res) => {
  const { idToken, role = 'passenger' } = req.body;

  if (!idToken) {
    throw ApiError.badRequest('Google ID token is required');
  }

  // Verify token with Google (Node 18+ built-in fetch)
  const verifyUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
  const googleRes = await fetch(verifyUrl);

  if (!googleRes.ok) {
    throw ApiError.unauthorized('Invalid Google token');
  }

  const payload = await googleRes.json();
  const email = (payload.email || '').toLowerCase().trim();
  const name = payload.name || payload.given_name || 'User';
  const googleId = payload.sub;

  if (!email) {
    throw ApiError.badRequest('Google account has no email');
  }

  if (payload.email_verified !== 'true' && payload.email_verified !== true) {
    throw ApiError.badRequest('Google email not verified');
  }

  const adminEmail = process.env.ADMIN_EMAIL ? process.env.ADMIN_EMAIL.toLowerCase().trim() : null;
  const isAppAdmin = adminEmail && email === adminEmail;
  const effectiveRole = isAppAdmin ? 'union_admin' : role;

  // Check if user exists
  const existingUser = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [email]
  );

  let user;
  let isNewUser = false;

  if (existingUser.rows.length > 0) {
    user = existingUser.rows[0];

    if (!user.is_active) {
      throw ApiError.forbidden('Account is deactivated');
    }

    // Update google_id if not set, and last_login
    await pool.query(
      `UPDATE users SET google_id = COALESCE(google_id, $1), last_login = CURRENT_TIMESTAMP WHERE id = $2`,
      [googleId, user.id]
    );
  } else {
    // Create new user
    isNewUser = true;
    const phonePlaceholder = `G${Date.now().toString().slice(-14)}`;

    const result = await pool.query(
      `INSERT INTO users (name, email, google_id, role, is_verified, is_active, phone)
       VALUES ($1, $2, $3, $4, TRUE, TRUE, $5)
       RETURNING id, name, email, role, is_verified, is_active, driver_verification_status, driver_kyc_reupload_allowed, driver_code, created_at`,
      [name, email, googleId, effectiveRole, phonePlaceholder]
    );

    user = result.rows[0];
    logger.info(`New Google user created: ${user.id} - ${email}`);
  }

  // Generate our JWT tokens
  const tokens = await generateTokenPair(
    user.id,
    user.role,
    { userAgent: req.headers['user-agent'] },
    req.ip
  );

  // Log login
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
 *
 * Mobile app verifies the email link via Firebase Auth SDK,
 * gets a Firebase ID token, and sends it here.
 * We verify with Google's tokeninfo, extract email, find-or-create user.
 */
const firebaseEmailSignIn = asyncHandler(async (req, res) => {
  const { idToken, name, role = 'passenger' } = req.body;

  if (!idToken) {
    throw ApiError.badRequest('Firebase ID token is required');
  }

  // Verify Firebase ID token using Google's secure token verification
  const verifyUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
  const googleRes = await fetch(verifyUrl);

  if (!googleRes.ok) {
    throw ApiError.unauthorized('Invalid Firebase token');
  }

  const payload = await googleRes.json();
  const email = (payload.email || '').toLowerCase().trim();
  const displayName = name || payload.name || 'User';
  const firebaseUid = payload.sub;

  if (!email) {
    throw ApiError.badRequest('No email in Firebase token');
  }

  const adminEmail = process.env.ADMIN_EMAIL ? process.env.ADMIN_EMAIL.toLowerCase().trim() : null;
  const isAppAdmin = adminEmail && email === adminEmail;
  const effectiveRole = isAppAdmin ? 'union_admin' : role;

  // Check if user exists
  const existingUser = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [email]
  );

  let user;
  let isNewUser = false;

  if (existingUser.rows.length > 0) {
    user = existingUser.rows[0];

    if (!user.is_active) {
      throw ApiError.forbidden('Account is deactivated');
    }

    await pool.query(
      'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1',
      [user.id]
    );
  } else {
    isNewUser = true;
    const phonePlaceholder = `F${Date.now().toString().slice(-14)}`;

    const result = await pool.query(
      `INSERT INTO users (name, email, firebase_uid, role, is_verified, is_active, phone)
       VALUES ($1, $2, $3, $4, TRUE, TRUE, $5)
       RETURNING id, name, email, role, is_verified, is_active, driver_verification_status, driver_kyc_reupload_allowed, driver_code, created_at`,
      [displayName, email, firebaseUid, effectiveRole, phonePlaceholder]
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
