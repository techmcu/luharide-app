const { pool } = require('../config/database');
const { generateTokenPair } = require('../services/tokenService');
const { createOTPByEmail, verifyOTPByEmail, sendOTPByEmail } = require('../services/otpService');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const bcrypt = require('bcryptjs');

/**
 * Simple Signup - No OTP
 * POST /api/simple-auth/signup
 */
const signup = asyncHandler(async (req, res) => {
  const { email, password, name, role = 'passenger' } = req.body;
  const emailNorm = (email || '').toLowerCase().trim();
  const adminEmail = process.env.ADMIN_EMAIL ? process.env.ADMIN_EMAIL.toLowerCase().trim() : null;
  const isAppAdmin = adminEmail && emailNorm === adminEmail;
  const effectiveRole = isAppAdmin ? 'union_admin' : role;

  const passwordHash = await bcrypt.hash(password, 10);

  let user;
  try {
    const result = await pool.query(
      `INSERT INTO users (name, email, password_hash, role, is_verified, is_active)
       VALUES ($1, $2, $3, $4, TRUE, TRUE)
       RETURNING id, name, email, role, is_verified, is_active, driver_verification_status, driver_kyc_reupload_allowed, driver_code, created_at`,
      [name, emailNorm, passwordHash, effectiveRole]
    );
    user = result.rows[0];
  } catch (err) {
    if (err.code === '23505' && err.constraint?.includes('email')) {
      throw ApiError.conflict('An account with this email already exists. Please login instead.');
    }
    throw err;
  }

  const tokens = await generateTokenPair(
    user.id,
    user.role,
    { userAgent: req.headers['user-agent'] },
    req.ip
  );

  logger.info(`New user signed up: ${user.id} - ${email}`);

  ApiResponse.created(
    {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        isVerified: user.is_verified,
        isActive: user.is_active,
        driverVerificationStatus: user.driver_verification_status || 'none',
        driverKycReuploadAllowed: user.driver_kyc_reupload_allowed === true,
        driverCode: user.driver_code || null,
        has_password: true,
        isAppAdmin
      },
      tokens
    },
    'Signup successful'
  ).send(res);
});

/**
 * Simple Login - Email + Password
 * POST /api/simple-auth/login
 */
const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  const emailNorm = (email || '').toLowerCase().trim();
  const adminEmail = process.env.ADMIN_EMAIL ? process.env.ADMIN_EMAIL.toLowerCase().trim() : null;
  const isAppAdmin = adminEmail && emailNorm === adminEmail;

  const MAX_FAILED_ATTEMPTS = 10;
  const LOCKOUT_MINUTES = 30;

  let result;
  try {
    result = await pool.query(
      `SELECT id, name, email, role, is_verified, is_active, password_hash,
              driver_verification_status, driver_kyc_reupload_allowed, driver_code,
              failed_login_attempts, locked_until
       FROM users WHERE email = $1`,
      [emailNorm]
    );
  } catch (err) {
    if (err.code === '42703') {
      result = await pool.query(
        `SELECT id, name, email, role, is_verified, is_active, password_hash,
                driver_verification_status, driver_kyc_reupload_allowed, driver_code
         FROM users WHERE email = $1`,
        [emailNorm]
      );
    } else {
      throw err;
    }
  }

  if (result.rows.length === 0) {
    throw ApiError.unauthorized('Invalid email or password');
  }

  const user = result.rows[0];

  if (!user.is_active) {
    throw ApiError.unauthorized('Invalid email or password');
  }

  if (user.locked_until && new Date(user.locked_until) > new Date()) {
    const minsLeft = Math.ceil((new Date(user.locked_until) - new Date()) / 60000);
    throw ApiError.tooManyRequests(`Account temporarily locked. Try again in ${minsLeft} minute(s).`);
  }

  if (!user.password_hash) {
    throw ApiError.unauthorized('Invalid email or password');
  }
  const isValidPassword = await bcrypt.compare(password, user.password_hash);

  if (!isValidPassword) {
    const attempts = (user.failed_login_attempts || 0) + 1;
    try {
      if (attempts >= MAX_FAILED_ATTEMPTS) {
        await pool.query(
          `UPDATE users SET failed_login_attempts = $1, locked_until = NOW() + make_interval(mins => $3) WHERE id = $2`,
          [attempts, user.id, LOCKOUT_MINUTES]
        );
      } else {
        await pool.query(
          'UPDATE users SET failed_login_attempts = $1 WHERE id = $2',
          [attempts, user.id]
        );
      }
    } catch (_) { /* lockout columns may not exist yet */ }
    if (attempts >= MAX_FAILED_ATTEMPTS) {
      throw ApiError.tooManyRequests(`Too many failed attempts. Account locked for ${LOCKOUT_MINUTES} minutes.`);
    }
    throw ApiError.unauthorized('Invalid email or password');
  }

  if (adminEmail && emailNorm === adminEmail && user.role !== 'union_admin') {
    try {
      await pool.query(
        "UPDATE users SET role = 'union_admin', failed_login_attempts = 0, locked_until = NULL, last_login = CURRENT_TIMESTAMP WHERE id = $1",
        [user.id]
      );
    } catch (e) {
      if (e.code === '42703') {
        await pool.query("UPDATE users SET role = 'union_admin', last_login = CURRENT_TIMESTAMP WHERE id = $1", [user.id]);
      } else { throw e; }
    }
    user.role = 'union_admin';
  } else {
    try {
      await pool.query(
        'UPDATE users SET failed_login_attempts = 0, locked_until = NULL, last_login = CURRENT_TIMESTAMP WHERE id = $1',
        [user.id]
      );
    } catch (e) {
      if (e.code === '42703') {
        await pool.query('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1', [user.id]);
      } else { throw e; }
    }
  }

  // Generate tokens
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
    [user.id, 'password', JSON.stringify({}), req.ip, req.headers['user-agent'], 'success']
  );

  logger.info(`User logged in: ${user.id} - ${email}`);

  ApiResponse.success(
    {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        isVerified: user.is_verified,
        isActive: user.is_active,
        driverVerificationStatus: user.driver_verification_status || 'none',
        driverKycReuploadAllowed: user.driver_kyc_reupload_allowed === true,
        has_password: !!user.password_hash,
        isAppAdmin
      },
      tokens
    },
    'Login successful'
  ).send(res);
});

/**
 * Create Demo Accounts
 * POST /api/simple-auth/create-demo
 *
 * NOTE: All hard-coded demo users have been removed for security reasons.
 * This endpoint is now effectively a no-op and kept only for backwards compatibility in development.
 */
const createDemoAccounts = asyncHandler(async (req, res) => {
  ApiResponse.success(
    { created: [], message: 'Demo account creation is disabled' },
    'Demo accounts are disabled'
  ).send(res);
});

/**
 * Change password for email/password users
 * POST /api/simple-auth/change-password
 */
const changePassword = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const { currentPassword, newPassword } = req.body;

  if (!newPassword) {
    throw ApiError.badRequest('New password is required');
  }

  const result = await pool.query(
    'SELECT password_hash FROM users WHERE id = $1',
    [userId]
  );

  if (result.rows.length === 0) {
    throw ApiError.notFound('User not found');
  }

  const user = result.rows[0];
  const hasExistingPassword = !!user.password_hash;

  if (hasExistingPassword) {
    if (!currentPassword) {
      throw ApiError.badRequest('Current password is required');
    }
    const isValidPassword = await bcrypt.compare(currentPassword, user.password_hash);
    if (!isValidPassword) {
      throw ApiError.badRequest('Current password is incorrect');
    }
  }

  const newHash = await bcrypt.hash(newPassword, 10);
  await pool.query(
    'UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
    [newHash, userId]
  );

  const action = hasExistingPassword ? 'changed' : 'set';
  logger.info(`Password ${action} for user ${userId}`);

  ApiResponse.success(null, hasExistingPassword ? 'Password updated successfully' : 'Password set successfully').send(res);
});

/**
 * Request password reset (email-based, OTP flow).
 * POST /api/simple-auth/forgot-password
 */
const requestPasswordReset = asyncHandler(async (req, res) => {
  const { email } = req.body;
  const emailNorm = (email || '').toLowerCase().trim();

  // Even if user doesn't exist, respond success (avoid user enumeration).
  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [emailNorm]);
  if (existing.rows.length === 0) {
    logger.info(`Password reset requested for non-existing email: ${emailNorm}`);
    ApiResponse.success(
      { email: emailNorm },
      'If an account exists for this email, a reset OTP has been sent.'
    ).send(res);
    return;
  }

  let otpData;
  try {
    otpData = await createOTPByEmail(emailNorm, 'password_reset');
  } catch (err) {
    logger.error('Password reset: createOTPByEmail failed', { message: err.message, code: err.code });
    if (err.code === '42703' || err.message?.includes('otp_verifications')) {
      throw ApiError.internal('Database migration pending for OTP system. Ask server admin to run migrations.');
    }
    throw err;
  }

  sendOTPByEmail(emailNorm, otpData.otp).catch((err) => {
    logger.error('Password reset: sendOTPByEmail failed (async)', {
      email: emailNorm,
      message: err.message,
    });
  });
  logger.info(`Password reset OTP queued for ${emailNorm}`);

  ApiResponse.success(
    {
      email: emailNorm,
      expiresIn: '10 minutes',
      // In development we already log OTP in otpService; no need to expose here.
    },
    'If an account exists for this email, a reset OTP has been sent.'
  ).send(res);
});

/**
 * Reset password using email + OTP.
 * POST /api/simple-auth/reset-password
 */
const resetPassword = asyncHandler(async (req, res) => {
  const { email, otp, newPassword } = req.body;
  const emailNorm = (email || '').toLowerCase().trim();

  // Verify OTP for this email
  const verification = await verifyOTPByEmail(emailNorm, otp);
  if (!verification.verified) {
    throw ApiError.badRequest('OTP verification failed');
  }
  if (verification.purpose && verification.purpose !== 'password_reset') {
    throw ApiError.badRequest('OTP verification failed');
  }

  // Ensure user exists
  const result = await pool.query(
    'SELECT id FROM users WHERE email = $1',
    [emailNorm]
  );
  if (result.rows.length === 0) {
    // For security: behave as if success, even if user is missing
    logger.warn(`Password reset: user not found for email ${emailNorm} after OTP verified`);
    ApiResponse.success(
      null,
      'Password updated successfully'
    ).send(res);
    return;
  }

  const userId = result.rows[0].id;
  const newHash = await bcrypt.hash(newPassword, 10);

  await pool.query(
    'UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
    [newHash, userId]
  );

  logger.info(`Password reset via OTP for user ${userId}`);

  ApiResponse.success(
    null,
    'Password updated successfully. You can now login with your new password.'
  ).send(res);
});

module.exports = {
  signup,
  login,
  createDemoAccounts,
  changePassword,
  requestPasswordReset,
  resetPassword
};
