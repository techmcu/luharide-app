const { pool } = require('../config/database');
const { verifyAccessToken } = require('../services/tokenService');
const ApiError = require('../utils/ApiError');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

/**
 * Authenticate user with JWT token
 */
const authenticate = asyncHandler(async (req, res, next) => {
  // Get token from header
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    throw ApiError.unauthorized('No token provided');
  }

  const token = authHeader.substring(7); // Remove 'Bearer ' prefix

  // Verify token
  const decoded = verifyAccessToken(token);

  // Get user from database
  const result = await pool.query(
    'SELECT id, name, email, phone, role, is_active, is_verified, driver_verification_status FROM users WHERE id = $1',
    [decoded.userId]
  );

  if (result.rows.length === 0) {
    throw ApiError.unauthorized('User not found');
  }

  const user = result.rows[0];

  // Check if user is active
  if (!user.is_active) {
    throw ApiError.forbidden('Account is deactivated');
  }

  // Attach user to request
  req.user = user;
  req.token = token;

  logger.info(`✅ Authenticated user: ${user.name} (${user.email}) - Role: ${user.role}`);

  next();
});

/**
 * Authorize based on roles
 */
const authorize = (...roles) => {
  return asyncHandler(async (req, res, next) => {
    if (!req.user) {
      throw ApiError.unauthorized('Authentication required');
    }

    // Trim + lowercase so "Passenger" / spacing mismatches don't break RBAC
    const userRole = String(req.user.role ?? '').trim().toLowerCase();
    const allowed = roles.map((r) => String(r).trim().toLowerCase());
    logger.info(`🔐 Authorization check:`);
    logger.info(`   User role: "${userRole}" (type: ${typeof userRole}, length: ${userRole.length})`);
    logger.info(`   Required roles: [${allowed.join(', ')}]`);

    if (!allowed.includes(userRole)) {
      logger.warn(`❌ Access denied for ${req.user.email}`);
      logger.warn(`   User role "${userRole}" not in [${allowed.join(', ')}]`);
      throw ApiError.forbidden(`Access denied. Required roles: ${roles.join(', ')}`);
    }

    logger.info(`✅ Authorization passed for ${req.user.email}`);
    next();
  });
};

/**
 * Optional authentication - doesn't fail if no token
 */
const optionalAuth = asyncHandler(async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.substring(7);
      const decoded = verifyAccessToken(token);

      const result = await pool.query(
        'SELECT id, name, email, phone, role, is_active, driver_verification_status FROM users WHERE id = $1',
        [decoded.userId]
      );

      if (result.rows.length > 0 && result.rows[0].is_active) {
        req.user = result.rows[0];
        req.token = token;
      }
    }
  } catch (error) {
    // Silently fail for optional auth
    logger.debug('Optional auth failed:', error.message);
  }
  
  next();
});

/**
 * Check if user is verified
 */
const requireVerified = asyncHandler(async (req, res, next) => {
  if (!req.user) {
    throw ApiError.unauthorized('Authentication required');
  }

  if (!req.user.is_verified) {
    throw ApiError.forbidden('Phone verification required');
  }

  next();
});

module.exports = {
  authenticate,
  authorize,
  optionalAuth,
  requireVerified
};
