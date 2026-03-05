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

  // Check if user exists
  const existingUser = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [emailNorm]
  );

  if (existingUser.rows.length > 0) {
    throw ApiError.conflict('Email already registered');
  }

  // Hash password
  const passwordHash = await bcrypt.hash(password, 10);

  // Create user (phone VARCHAR(15) UNIQUE - use placeholder for email-only signup)
  const phonePlaceholder = `E${Date.now().toString().slice(-14)}`;
  const result = await pool.query(
    `INSERT INTO users (name, email, password_hash, role, is_verified, is_active, phone)
     VALUES ($1, $2, $3, $4, TRUE, TRUE, $5)
     RETURNING id, name, email, role, is_verified, is_active, driver_verification_status, driver_code, created_at`,
    [name, emailNorm, passwordHash, effectiveRole, phonePlaceholder]
  );

  const user = result.rows[0];
  if (user && !user.driver_verification_status) {
    user.driver_verification_status = 'none';
  }

  // Generate tokens
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
        driverCode: user.driver_code || null,
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

  // Find user
  const result = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [emailNorm]
  );

  if (result.rows.length === 0) {
    throw ApiError.unauthorized('Invalid email or password');
  }

  const user = result.rows[0];

  // Check if active
  if (!user.is_active) {
    throw ApiError.forbidden('Account is deactivated');
  }

  // Verify password
  const isValidPassword = await bcrypt.compare(password, user.password_hash);

  if (!isValidPassword) {
    throw ApiError.unauthorized('Invalid email or password');
  }

  // If this email is configured as admin, ensure role is union_admin
  if (adminEmail && emailNorm === adminEmail && user.role !== 'union_admin') {
    await pool.query("UPDATE users SET role = 'union_admin', last_login = CURRENT_TIMESTAMP WHERE id = $1", [user.id]);
    user.role = 'union_admin';
  } else {
    await pool.query(
      'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1',
      [user.id]
    );
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
 */
const createDemoAccounts = asyncHandler(async (req, res) => {
  const demoAccounts = [
    { email: 'passenger@demo.com', password: 'demo123', name: 'Demo Passenger', role: 'passenger' },
    { email: 'driver@demo.com', password: 'demo123', name: 'Demo Driver', role: 'driver' },
    { email: 'admin@demo.com', password: 'demo123', name: 'Demo Admin', role: 'union_admin' },
    { email: 'admin@luharide.com', password: 'Admin@123', name: 'LuhaRide Admin', role: 'union_admin' }
  ];

  const created = [];

  for (const account of demoAccounts) {
    const passwordHash = await bcrypt.hash(account.password, 10);
    const existing = await pool.query('SELECT id FROM users WHERE email = $1', [account.email]);

    if (existing.rows.length === 0) {
      const phonePlaceholder = account.email.slice(0, 15) || `D${Date.now().toString().slice(-14)}`;
      const result = await pool.query(
        `INSERT INTO users (name, email, password_hash, role, is_verified, is_active, phone, driver_verification_status)
         VALUES ($1, $2, $3, $4, TRUE, TRUE, $5, $6)
         RETURNING id, name, email, role`,
        [account.name, account.email, passwordHash, account.role, phonePlaceholder, account.role === 'driver' ? 'approved' : 'none']
      );
      created.push(result.rows[0]);

      // For demo driver: add driver_verification_requests with Mahindra Bolero 7-seater
      if (account.role === 'driver') {
        const driverId = result.rows[0].id;
        await pool.query(
          `INSERT INTO driver_verification_requests (
            user_id, driving_license_number, vehicle_registration, vehicle_type, vehicle_model, vehicle_model_id, vehicle_capacity, status
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'approved')
          ON CONFLICT (user_id) DO UPDATE SET
            vehicle_capacity = EXCLUDED.vehicle_capacity,
            vehicle_registration = EXCLUDED.vehicle_registration,
            vehicle_type = EXCLUDED.vehicle_type,
            vehicle_model = EXCLUDED.vehicle_model,
            vehicle_model_id = EXCLUDED.vehicle_model_id,
            status = 'approved',
            updated_at = CURRENT_TIMESTAMP`,
          [driverId, 'DL-DEMO-001', 'DEMO-001', 'SUV', 'Mahindra Bolero 7-Seater', 'mahindra_bolero_suv', 7]
        );
      }
    } else {
      // For demo accounts, always reset password + role + name to known values
      const userId = existing.rows[0].id;
      await pool.query(
        'UPDATE users SET password_hash = $1, role = $2, name = $3, is_verified = TRUE, is_active = TRUE, driver_verification_status = $5 WHERE email = $4',
        [passwordHash, account.role, account.name, account.email, account.role === 'driver' ? 'approved' : 'none']
      );

      // For demo driver: ensure driver_verification_requests exists with vehicle
      if (account.role === 'driver') {
        await pool.query(
          `INSERT INTO driver_verification_requests (
            user_id, driving_license_number, vehicle_registration, vehicle_type, vehicle_model, vehicle_model_id, vehicle_capacity, status
          ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'approved')
          ON CONFLICT (user_id) DO UPDATE SET
            vehicle_capacity = EXCLUDED.vehicle_capacity,
            vehicle_registration = EXCLUDED.vehicle_registration,
            vehicle_type = EXCLUDED.vehicle_type,
            vehicle_model = EXCLUDED.vehicle_model,
            vehicle_model_id = EXCLUDED.vehicle_model_id,
            status = 'approved',
            updated_at = CURRENT_TIMESTAMP`,
          [userId, 'DL-DEMO-001', 'DEMO-001', 'SUV', 'Mahindra Bolero 7-Seater', 'mahindra_bolero_suv', 7]
        );
      }
    }
  }

  ApiResponse.success(
    { created, message: 'Demo accounts ready' },
    `Created ${created.length} demo accounts`
  ).send(res);
});

/**
 * Change password for email/password users
 * POST /api/simple-auth/change-password
 */
const changePassword = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const { currentPassword, newPassword } = req.body;

  if (!currentPassword || !newPassword) {
    throw ApiError.badRequest('Current and new password are required');
  }

  const result = await pool.query(
    'SELECT password_hash FROM users WHERE id = $1',
    [userId]
  );

  if (result.rows.length === 0) {
    throw ApiError.notFound('User not found');
  }

  const user = result.rows[0];
  const isValidPassword = await bcrypt.compare(currentPassword, user.password_hash);

  if (!isValidPassword) {
    throw ApiError.badRequest('Current password is incorrect');
  }

  const newHash = await bcrypt.hash(newPassword, 10);
  await pool.query(
    'UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
    [newHash, userId]
  );

  logger.info(`Password changed for user ${userId}`);

  ApiResponse.success(null, 'Password updated successfully').send(res);
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

  await sendOTPByEmail(emailNorm, otpData.otp);
  logger.info(`Password reset OTP sent to ${emailNorm}`);

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
    throw ApiError.badRequest('This OTP is not valid for password reset');
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
