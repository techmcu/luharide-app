const { pool } = require('../config/database');
const { createOTP, verifyOTP, sendOTP, createOTPByEmail, verifyOTPByEmail, sendOTPByEmail } = require('../services/otpService');
const { generateTokenPair, verifyRefreshToken, revokeRefreshToken } = require('../services/tokenService');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const bcrypt = require('bcryptjs');

/**
 * Send OTP to phone OR email
 * POST /api/auth/send-otp
 * Body: { phone } OR { email }, optional: { purpose }
 */
const sendOTPController = asyncHandler(async (req, res) => {
  const { phone, email, purpose = 'login' } = req.body;

  if (email) {
    const emailNorm = email.toLowerCase().trim();
    const isSignup = purpose === 'registration' || purpose === 'signup';
    if (isSignup) {
      const existing = await pool.query('SELECT id FROM users WHERE email = $1 LIMIT 1', [emailNorm]);
      if (existing.rows.length > 0) {
        throw ApiError.conflict('This email is already registered. Please login.');
      }
    }
    let otpData;
    try {
      otpData = await createOTPByEmail(emailNorm, purpose);
    } catch (err) {
      logger.error('send-otp createOTPByEmail failed:', err.message);
      if (err.code === '42703' || err.message?.includes('column')) {
        throw ApiError.internal('Database migration pending. Run: npm run migrate');
      }
      throw err;
    }
    await sendOTPByEmail(emailNorm, otpData.otp);
    const responseData = {
      message: 'OTP sent to your email',
      email: emailNorm,
      expiresIn: '10 minutes',
      ...(process.env.NODE_ENV === 'development' && { otp: otpData.otp })
    };
    return ApiResponse.success(responseData, 'OTP sent successfully').send(res);
  }

  if (phone) {
    const isSignup = purpose === 'registration' || purpose === 'signup';
    if (isSignup) {
      const existing = await pool.query('SELECT id FROM users WHERE phone = $1 LIMIT 1', [phone]);
      if (existing.rows.length > 0) {
        throw ApiError.conflict('This number is already registered. Please login.');
      }
    }
    const otpData = await createOTP(phone, purpose);
    await sendOTP(phone, otpData.otp);
    const responseData = {
      message: 'OTP sent successfully',
      phone,
      expiresIn: '10 minutes',
      ...(process.env.NODE_ENV === 'development' && { otp: otpData.otp })
    };
    return ApiResponse.success(responseData, 'OTP sent successfully').send(res);
  }

  throw ApiError.badRequest('Provide either phone or email');
});

/**
 * Verify OTP and login/register (phone OR email)
 * POST /api/auth/verify-otp
 * Body: (phone + otp) OR (email + otp); for new user: name, role
 */
const verifyOTPController = asyncHandler(async (req, res) => {
  const { phone, email, otp, name, role = 'passenger', password } = req.body;

  let identifier; // 'phone' or 'email'
  let value;      // phone number or email

  if (email && otp) {
    identifier = 'email';
    value = email.toLowerCase().trim();
    const verification = await verifyOTPByEmail(value, otp);
    if (!verification.verified) throw ApiError.badRequest('OTP verification failed');
  } else if (phone && otp) {
    identifier = 'phone';
    value = phone;
    const verification = await verifyOTP(phone, otp);
    if (!verification.verified) throw ApiError.badRequest('OTP verification failed');
  } else {
    throw ApiError.badRequest('Provide (phone + otp) or (email + otp)');
  }

  const byPhone = identifier === 'phone';
  let userResult = await pool.query(
    byPhone ? 'SELECT * FROM users WHERE phone = $1' : 'SELECT * FROM users WHERE email = $1',
    [value]
  );

  const adminEmail = process.env.ADMIN_EMAIL ? process.env.ADMIN_EMAIL.toLowerCase().trim() : null;
  const isAppAdmin = !byPhone && adminEmail && value === adminEmail;
  const effectiveRole = isAppAdmin ? 'union_admin' : role;

  let user;
  let isNewUser = false;

  if (userResult.rows.length === 0) {
    if (!name || name.length < 2) {
      throw ApiError.badRequest('Name is required for registration (min 2 characters)');
    }
    const phonePlaceholder = byPhone ? value : `E${Date.now().toString().slice(-14)}`;
    const emailVal = byPhone ? null : value;
    const passwordHash = (!byPhone && password) ? await bcrypt.hash(password, 10) : null;
    const insertResult = await pool.query(
      `INSERT INTO users (name, phone, email, role, is_verified, is_active, password_hash)
       VALUES ($1, $2, $3, $4, TRUE, TRUE, $5)
       RETURNING id, name, phone, email, role, is_verified, is_active, driver_verification_status, created_at`,
      [name.trim(), phonePlaceholder, emailVal, effectiveRole, passwordHash]
    );
    user = insertResult.rows[0];
    isNewUser = true;
    logger.info(`New user registered: ${user.id} - ${value}${effectiveRole === 'union_admin' ? ' (admin)' : ''}`);
  } else {
    user = userResult.rows[0];
    if (!byPhone && adminEmail && value === adminEmail && user.role !== 'union_admin') {
      await pool.query(
        "UPDATE users SET role = 'union_admin', is_verified = TRUE, last_login = CURRENT_TIMESTAMP WHERE id = $1",
        [user.id]
      );
      user.role = 'union_admin';
    } else {
      await pool.query(
        'UPDATE users SET is_verified = TRUE, last_login = CURRENT_TIMESTAMP WHERE id = $1',
        [user.id]
      );
    }
    logger.info(`User logged in: ${user.id} - ${value}`);
  }

  if (!user.is_active) {
    throw ApiError.forbidden('Account is deactivated. Please contact support.');
  }

  const deviceInfo = {
    userAgent: req.headers['user-agent'],
    platform: req.body.platform || 'unknown'
  };
  const tokens = await generateTokenPair(user.id, user.role, deviceInfo, req.ip);

  await pool.query(
    `INSERT INTO login_history (user_id, login_type, device_info, ip_address, user_agent, status)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [user.id, 'otp', JSON.stringify(deviceInfo), req.ip, req.headers['user-agent'] || null, 'success']
  );

  const responseData = {
    user: {
      id: user.id,
      name: user.name,
      phone: user.phone,
      email: user.email,
      role: user.role,
      isVerified: user.is_verified,
      isActive: user.is_active,
      driverVerificationStatus: user.driver_verification_status || 'none',
      driverCode: user.driver_code || null,
      isAppAdmin
    },
    tokens,
    isNewUser
  };

  ApiResponse.success(
    responseData,
    isNewUser ? 'Registration successful' : 'Login successful'
  ).send(res);
});

/**
 * Refresh access token
 * POST /api/auth/refresh-token
 */
const refreshTokenController = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    throw ApiError.badRequest('Refresh token is required');
  }

  // Verify refresh token
  const decoded = await verifyRefreshToken(refreshToken);

  // Get user
  const userResult = await pool.query(
    'SELECT id, name, phone, email, role, is_active FROM users WHERE id = $1',
    [decoded.userId]
  );

  if (userResult.rows.length === 0) {
    throw ApiError.unauthorized('User not found');
  }

  const user = userResult.rows[0];

  if (!user.is_active) {
    throw ApiError.forbidden('Account is deactivated');
  }

  // Generate new token pair
  const deviceInfo = {
    userAgent: req.headers['user-agent'],
    platform: req.body.platform || 'unknown'
  };

  const tokens = await generateTokenPair(
    user.id,
    user.role,
    deviceInfo,
    req.ip
  );

  // Revoke old refresh token
  await revokeRefreshToken(refreshToken);

  ApiResponse.success(
    { tokens },
    'Token refreshed successfully'
  ).send(res);
});

/**
 * Logout user
 * POST /api/auth/logout
 */
const logoutController = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body;

  if (refreshToken) {
    try {
      await revokeRefreshToken(refreshToken);
    } catch (err) {
      // Token already revoked/expired - still return success
      logger.debug('Logout: refresh token already invalid or expired');
    }
  }

  logger.info(`User logged out${req.user ? `: ${req.user.id}` : ' (token revoked)'}`);

  ApiResponse.success(null, 'Logged out successfully').send(res);
});

/**
 * Get current user profile
 * GET /api/auth/me
 * Handles DB with or without bio/luggage columns (migration 013)
 */
const getCurrentUserController = asyncHandler(async (req, res) => {
  const baseCols = 'id, name, phone, email, role, profile_image_url, is_verified, is_active, driver_verification_status, whatsapp_number, last_login, created_at, updated_at, driver_code';
  let userResult;
  try {
    userResult = await pool.query(
      `SELECT ${baseCols}, bio, luggage_allowance_per_passenger FROM users WHERE id = $1`,
      [req.user.id]
    );
  } catch (err) {
    if (err.code === '42703') {
      userResult = await pool.query(`SELECT ${baseCols} FROM users WHERE id = $1`, [req.user.id]);
    } else {
      throw err;
    }
  }

  if (userResult.rows.length === 0) {
    throw ApiError.notFound('User not found');
  }

  const row = userResult.rows[0];
  if (row.bio === undefined) row.bio = null;
  if (row.luggage_allowance_per_passenger === undefined) row.luggage_allowance_per_passenger = null;

  const adminEmail = process.env.ADMIN_EMAIL ? process.env.ADMIN_EMAIL.toLowerCase().trim() : null;
  const emailNorm = row.email ? String(row.email).toLowerCase().trim() : null;
  row.isAppAdmin = !!(adminEmail && emailNorm && emailNorm === adminEmail);

  ApiResponse.success(row, 'User profile retrieved').send(res);
});

/**
 * Update user profile
 * PUT /api/auth/profile
 */
const MAX_BIO_WORDS = 20;

const updateProfileController = asyncHandler(async (req, res) => {
  const { name, phone, email, profile_image_url, whatsapp_number, bio, luggage_allowance_per_passenger } = req.body;
  const userId = req.user.id;

  // Build update query dynamically
  const updates = [];
  const values = [];
  let paramCount = 1;

  if (name) {
    updates.push(`name = $${paramCount++}`);
    values.push(name);
  }

  if (phone !== undefined) {
    const normalized = (phone === '' || phone === null)
      ? null
      : String(phone).replace(/\D/g, '');
    if (normalized !== null && !/^[6-9]\d{9}$/.test(normalized)) {
      throw ApiError.badRequest('Phone must be a valid 10-digit Indian mobile number');
    }
    if (normalized !== null) {
      const dup = await pool.query(
        'SELECT id FROM users WHERE phone = $1 AND id <> $2 LIMIT 1',
        [normalized, userId]
      );
      if (dup.rows.length > 0) {
        throw ApiError.conflict('This phone number is already used by another account');
      }
    }
    updates.push(`phone = $${paramCount++}`);
    values.push(normalized);
  }

  if (email !== undefined) {
    updates.push(`email = $${paramCount++}`);
    values.push(email === '' || email === null ? null : email);
  }

  if (profile_image_url !== undefined) {
    updates.push(`profile_image_url = $${paramCount++}`);
    values.push(profile_image_url === '' || profile_image_url === null ? null : profile_image_url);
  }

  if (whatsapp_number !== undefined) {
    updates.push(`whatsapp_number = $${paramCount++}`);
    values.push(whatsapp_number === '' || whatsapp_number === null ? null : whatsapp_number);
  }

  if (bio !== undefined) {
    const trimmed = (bio === '' || bio === null) ? null : String(bio).trim();
    if (trimmed) {
      const wordCount = trimmed.split(/\s+/).filter(Boolean).length;
      if (wordCount > MAX_BIO_WORDS) {
        throw ApiError.badRequest(`Bio must be at most ${MAX_BIO_WORDS} words (got ${wordCount})`);
      }
    }
    updates.push(`bio = $${paramCount++}`);
    values.push(trimmed);
  }

  if (luggage_allowance_per_passenger !== undefined) {
    updates.push(`luggage_allowance_per_passenger = $${paramCount++}`);
    values.push(luggage_allowance_per_passenger === '' || luggage_allowance_per_passenger === null ? null : String(luggage_allowance_per_passenger).trim().slice(0, 100));
  }

  if (updates.length === 0) {
    throw ApiError.badRequest('No fields to update');
  }

  values.push(userId);

  const result = await pool.query(
    `UPDATE users SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP
     WHERE id = $${paramCount}
     RETURNING id, name, phone, email, role, profile_image_url, whatsapp_number, is_verified, is_active, driver_verification_status, bio, luggage_allowance_per_passenger`,
    values
  );

  logger.info(`User profile updated: ${userId}`);

  ApiResponse.success(result.rows[0], 'Profile updated successfully').send(res);
});

module.exports = {
  sendOTPController,
  verifyOTPController,
  refreshTokenController,
  logoutController,
  getCurrentUserController,
  updateProfileController
};
