const { pool } = require('../config/database');
const { createOTP, verifyOTP, sendOTP } = require('../services/otpService');
const { generateTokenPair, verifyRefreshToken, revokeRefreshToken } = require('../services/tokenService');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

/**
 * Send OTP to phone number
 * POST /api/auth/send-otp
 */
const sendOTPController = asyncHandler(async (req, res) => {
  const { phone, purpose = 'login' } = req.body;

  // Create OTP
  const otpData = await createOTP(phone, purpose);

  // Send OTP via SMS
  await sendOTP(phone, otpData.otp);

  // In development, include OTP in response
  const responseData = {
    message: 'OTP sent successfully',
    phone,
    expiresIn: '10 minutes',
    ...(process.env.NODE_ENV === 'development' && { otp: otpData.otp })
  };

  ApiResponse.success(responseData, 'OTP sent successfully').send(res);
});

/**
 * Verify OTP and login/register
 * POST /api/auth/verify-otp
 */
const verifyOTPController = asyncHandler(async (req, res) => {
  const { phone, otp, name, role = 'passenger' } = req.body;

  // Verify OTP
  const otpVerification = await verifyOTP(phone, otp);

  if (!otpVerification.verified) {
    throw ApiError.badRequest('OTP verification failed');
  }

  // Check if user exists
  let userResult = await pool.query(
    'SELECT * FROM users WHERE phone = $1',
    [phone]
  );

  let user;
  let isNewUser = false;

  if (userResult.rows.length === 0) {
    // New user - create account
    if (!name) {
      throw ApiError.badRequest('Name is required for registration');
    }

    const insertResult = await pool.query(
      `INSERT INTO users (name, phone, role, is_verified, is_active)
       VALUES ($1, $2, $3, TRUE, TRUE)
       RETURNING id, name, phone, email, role, is_verified, is_active, created_at`,
      [name, phone, role]
    );

    user = insertResult.rows[0];
    isNewUser = true;
    logger.info(`New user registered: ${user.id} - ${phone}`);
  } else {
    // Existing user - login
    user = userResult.rows[0];

    // Update verification status and last login
    await pool.query(
      'UPDATE users SET is_verified = TRUE, last_login = CURRENT_TIMESTAMP WHERE id = $1',
      [user.id]
    );

    logger.info(`User logged in: ${user.id} - ${phone}`);
  }

  // Check if user is active
  if (!user.is_active) {
    throw ApiError.forbidden('Account is deactivated. Please contact support.');
  }

  // Generate tokens
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

  // Log login history
  await pool.query(
    `INSERT INTO login_history (user_id, login_type, device_info, ip_address, user_agent, status)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [user.id, 'otp', JSON.stringify(deviceInfo), req.ip, req.headers['user-agent'], 'success']
  );

  // Prepare response
  const responseData = {
    user: {
      id: user.id,
      name: user.name,
      phone: user.phone,
      email: user.email,
      role: user.role,
      isVerified: user.is_verified,
      isActive: user.is_active,
      driverVerificationStatus: user.driver_verification_status || 'none'
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
    await revokeRefreshToken(refreshToken);
  }

  logger.info(`User logged out: ${req.user?.id}`);

  ApiResponse.success(null, 'Logged out successfully').send(res);
});

/**
 * Get current user profile
 * GET /api/auth/me
 */
const getCurrentUserController = asyncHandler(async (req, res) => {
  const userResult = await pool.query(
    `SELECT id, name, phone, email, role, profile_image_url, is_verified, is_active, 
            driver_verification_status, whatsapp_number, last_login, created_at, updated_at
     FROM users WHERE id = $1`,
    [req.user.id]
  );

  if (userResult.rows.length === 0) {
    throw ApiError.notFound('User not found');
  }

  ApiResponse.success(userResult.rows[0], 'User profile retrieved').send(res);
});

/**
 * Update user profile
 * PUT /api/auth/profile
 */
const updateProfileController = asyncHandler(async (req, res) => {
  const { name, email, profile_image_url, whatsapp_number } = req.body;
  const userId = req.user.id;

  // Build update query dynamically
  const updates = [];
  const values = [];
  let paramCount = 1;

  if (name) {
    updates.push(`name = $${paramCount++}`);
    values.push(name);
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

  if (updates.length === 0) {
    throw ApiError.badRequest('No fields to update');
  }

  values.push(userId);

  const result = await pool.query(
    `UPDATE users SET ${updates.join(', ')}, updated_at = CURRENT_TIMESTAMP
     WHERE id = $${paramCount}
     RETURNING id, name, phone, email, role, profile_image_url, whatsapp_number, is_verified, is_active, driver_verification_status`,
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
