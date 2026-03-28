const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';
const REFRESH_TOKEN_EXPIRES_IN = process.env.REFRESH_TOKEN_EXPIRES_IN || '30d';

function hashRefreshToken(raw) {
  return crypto.createHash('sha256').update(String(raw), 'utf8').digest('hex');
}

/**
 * Generate access token (JWT)
 */
const generateAccessToken = (userId, role) => {
  const payload = {
    userId,
    role,
    type: 'access'
  };

  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: JWT_EXPIRES_IN
  });
};

/**
 * Generate refresh token
 */
const generateRefreshToken = (userId, role) => {
  const payload = {
    userId,
    role,
    type: 'refresh'
  };

  return jwt.sign(payload, JWT_SECRET, {
    expiresIn: REFRESH_TOKEN_EXPIRES_IN
  });
};

/**
 * Store refresh token in database (SHA-256 hash only when token_hash column exists).
 */
const storeRefreshToken = async (userId, token, deviceInfo = {}, ipAddress = null) => {
  try {
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days
    const tokenHash = hashRefreshToken(token);

    try {
      const result = await pool.query(
        `INSERT INTO refresh_tokens (user_id, token, token_hash, device_info, ip_address, expires_at)
         VALUES ($1, NULL, $2, $3, $4, $5)
         RETURNING id`,
        [userId, tokenHash, JSON.stringify(deviceInfo), ipAddress, expiresAt]
      );
      logger.info(`Refresh token stored (hashed) for user: ${userId}`);
      return result.rows[0].id;
    } catch (e) {
      // Pre-migration DB: no token_hash column or token NOT NULL
      if (e.code === '42703' || e.code === '23502') {
        const result = await pool.query(
          `INSERT INTO refresh_tokens (user_id, token, device_info, ip_address, expires_at)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING id`,
          [userId, token, JSON.stringify(deviceInfo), ipAddress, expiresAt]
        );
        logger.info(`Refresh token stored (legacy plaintext) for user: ${userId}`);
        return result.rows[0].id;
      }
      throw e;
    }
  } catch (error) {
    logger.error('Error storing refresh token:', error);
    throw ApiError.internal('Failed to store refresh token');
  }
};

/**
 * Verify access token
 */
const verifyAccessToken = (token) => {
  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    if (decoded.type !== 'access') {
      throw ApiError.unauthorized('Invalid token type');
    }

    return decoded;
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw ApiError.unauthorized('Token expired');
    }
    if (error.name === 'JsonWebTokenError') {
      throw ApiError.unauthorized('Invalid token');
    }
    throw error;
  }
};

/**
 * Verify refresh token
 */
const verifyRefreshToken = async (token) => {
  try {
    const decoded = jwt.verify(token, JWT_SECRET);

    if (decoded.type !== 'refresh') {
      throw ApiError.unauthorized('Invalid token type');
    }

    const tokenHash = hashRefreshToken(token);

    let result;
    try {
      result = await pool.query(
        `SELECT * FROM refresh_tokens
         WHERE is_revoked = FALSE AND expires_at > CURRENT_TIMESTAMP
           AND (
             (token_hash IS NOT NULL AND token_hash = $1)
             OR (token IS NOT NULL AND token = $2)
           )`,
        [tokenHash, token]
      );
    } catch (e) {
      if (e.code === '42703') {
        result = await pool.query(
          `SELECT * FROM refresh_tokens
           WHERE token = $1 AND is_revoked = FALSE AND expires_at > CURRENT_TIMESTAMP`,
          [token]
        );
      } else {
        throw e;
      }
    }

    if (result.rows.length === 0) {
      throw ApiError.unauthorized('Refresh token is invalid or expired');
    }

    return {
      ...decoded,
      tokenId: result.rows[0].id
    };
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      throw ApiError.unauthorized('Refresh token expired');
    }
    if (error.name === 'JsonWebTokenError') {
      throw ApiError.unauthorized('Invalid refresh token');
    }
    throw error;
  }
};

/**
 * Revoke refresh token
 */
const revokeRefreshToken = async (token) => {
  try {
    const tokenHash = hashRefreshToken(token);

    let result;
    try {
      result = await pool.query(
        `UPDATE refresh_tokens
         SET is_revoked = TRUE, revoked_at = CURRENT_TIMESTAMP
         WHERE is_revoked = FALSE
           AND ((token_hash IS NOT NULL AND token_hash = $1) OR (token IS NOT NULL AND token = $2))
         RETURNING id`,
        [tokenHash, token]
      );
    } catch (e) {
      if (e.code === '42703') {
        result = await pool.query(
          `UPDATE refresh_tokens
           SET is_revoked = TRUE, revoked_at = CURRENT_TIMESTAMP
           WHERE token = $1
           RETURNING id`,
          [token]
        );
      } else {
        throw e;
      }
    }

    if (result.rows.length === 0) {
      throw ApiError.notFound('Refresh token not found');
    }

    logger.info(`Refresh token revoked: ${result.rows[0].id}`);
    return true;
  } catch (error) {
    logger.error('Error revoking refresh token:', error);
    throw error;
  }
};

/**
 * Revoke all refresh tokens for a user
 */
const revokeAllUserTokens = async (userId) => {
  try {
    const result = await pool.query(
      `UPDATE refresh_tokens
       SET is_revoked = TRUE, revoked_at = CURRENT_TIMESTAMP
       WHERE user_id = $1 AND is_revoked = FALSE
       RETURNING id`,
      [userId]
    );

    logger.info(`Revoked ${result.rowCount} tokens for user: ${userId}`);
    return result.rowCount;
  } catch (error) {
    logger.error('Error revoking user tokens:', error);
    throw ApiError.internal('Failed to revoke tokens');
  }
};

/**
 * Clean up expired tokens (run periodically)
 */
const cleanupExpiredTokens = async () => {
  try {
    const result = await pool.query(
      'DELETE FROM refresh_tokens WHERE expires_at < CURRENT_TIMESTAMP'
    );
    logger.info(`Cleaned up ${result.rowCount} expired tokens`);
    return result.rowCount;
  } catch (error) {
    logger.error('Error cleaning up tokens:', error);
  }
};

/**
 * Generate both access and refresh tokens
 */
const generateTokenPair = async (userId, role, deviceInfo = {}, ipAddress = null) => {
  const accessToken = generateAccessToken(userId, role);
  const refreshToken = generateRefreshToken(userId, role);

  await storeRefreshToken(userId, refreshToken, deviceInfo, ipAddress);

  return {
    accessToken,
    refreshToken
  };
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  generateTokenPair,
  storeRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  revokeRefreshToken,
  revokeAllUserTokens,
  cleanupExpiredTokens
};
