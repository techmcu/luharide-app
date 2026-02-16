const { pool } = require('../config/database');
const { generateTokenPair } = require('../services/tokenService');
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

  // Check if user exists
  const existingUser = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [email]
  );

  if (existingUser.rows.length > 0) {
    throw ApiError.conflict('Email already registered');
  }

  // Hash password
  const passwordHash = await bcrypt.hash(password, 10);

  // Create user
  const result = await pool.query(
    `INSERT INTO users (name, email, password_hash, role, is_verified, is_active, phone)
     VALUES ($1, $2, $3, $4, TRUE, TRUE, $5)
     RETURNING id, name, email, role, is_verified, is_active, driver_verification_status, created_at`,
    [name, email, passwordHash, role, email] // Using email as phone for now
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
        driverVerificationStatus: user.driver_verification_status || 'none'
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

  // Find user
  const result = await pool.query(
    'SELECT * FROM users WHERE email = $1',
    [email]
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

  // Update last login
  await pool.query(
    'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1',
    [user.id]
  );

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
        driverVerificationStatus: user.driver_verification_status || 'none'
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
      const result = await pool.query(
        `INSERT INTO users (name, email, password_hash, role, is_verified, is_active, phone, driver_verification_status)
         VALUES ($1, $2, $3, $4, TRUE, TRUE, $5, $6)
         RETURNING id, name, email, role`,
        [account.name, account.email, passwordHash, account.role, account.email, account.role === 'driver' ? 'approved' : 'none']
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

module.exports = {
  signup,
  login,
  createDemoAccounts,
  changePassword
};
