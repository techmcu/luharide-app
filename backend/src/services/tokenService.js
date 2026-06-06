const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');

const { config } = require('../config/env');
const JWT_SECRET = config.jwt.secret;
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || JWT_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '1h';
const REFRESH_TOKEN_EXPIRES_IN = process.env.REFRESH_TOKEN_EXPIRES_IN || '30d';

function hashRefreshToken(raw) {
  return crypto.createHash('sha256').update(String(raw), 'utf8').digest('hex');
}

// ── Schema state (detected once at startup, used for every request) ──
let _schemaReady = false;
let _hasTokenHash = false;

async function ensureSchema() {
  if (_schemaReady) return;
  try {
    const col = await pool.query(
      `SELECT column_name FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'refresh_tokens' AND column_name = 'token_hash'`
    );
    if (col.rows.length > 0) {
      _hasTokenHash = true;
      await pool.query('ALTER TABLE refresh_tokens ALTER COLUMN token DROP NOT NULL').catch(() => {});
      logger.info('[TokenService] schema: token_hash column present, hashed mode active');
    } else {
      _hasTokenHash = false;
      logger.info('[TokenService] schema: token_hash column missing, plaintext mode active — run migration 033');
    }
    _schemaReady = true;
  } catch (err) {
    logger.error(`[TokenService] schema detection failed: ${err.message}`);
    _hasTokenHash = false;
    _schemaReady = true;
  }
}

const generateAccessToken = (userId, role) => {
  return jwt.sign({ userId, role, type: 'access' }, JWT_SECRET, {
    algorithm: 'HS256',
    expiresIn: JWT_EXPIRES_IN,
  });
};

const generateRefreshToken = (userId, role) => {
  return jwt.sign(
    { userId, role, type: 'refresh', jti: crypto.randomBytes(16).toString('hex') },
    JWT_REFRESH_SECRET,
    { algorithm: 'HS256', expiresIn: REFRESH_TOKEN_EXPIRES_IN }
  );
};

const storeRefreshToken = async (userId, token, deviceInfo = {}, ipAddress = null) => {
  await ensureSchema();
  const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
  const deviceJson = JSON.stringify(deviceInfo || {});

  try {
    if (_hasTokenHash) {
      const tokenHash = hashRefreshToken(token);
      const result = await pool.query(
        `INSERT INTO refresh_tokens (user_id, token, token_hash, device_info, ip_address, expires_at)
         VALUES ($1, NULL, $2, $3, $4, $5)
         RETURNING id`,
        [userId, tokenHash, deviceJson, ipAddress, expiresAt]
      );
      return result.rows[0].id;
    }

    const result = await pool.query(
      `INSERT INTO refresh_tokens (user_id, token, device_info, ip_address, expires_at)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [userId, token, deviceJson, ipAddress, expiresAt]
    );
    return result.rows[0].id;
  } catch (err) {
    if (err.code === '23505') {
      logger.warn(`[TokenService] duplicate token hash — revoking stale entry and retrying`);
      const tokenHash = hashRefreshToken(token);
      await pool.query(
        `UPDATE refresh_tokens SET is_revoked = TRUE, revoked_at = CURRENT_TIMESTAMP
         WHERE token_hash = $1 AND is_revoked = FALSE`,
        [tokenHash]
      );
      const retry = await pool.query(
        `INSERT INTO refresh_tokens (user_id, token, token_hash, device_info, ip_address, expires_at)
         VALUES ($1, NULL, $2, $3, $4, $5)
         RETURNING id`,
        [userId, tokenHash, JSON.stringify(deviceInfo || {}), ipAddress, new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)]
      );
      return retry.rows[0].id;
    }
    logger.error(`[TokenService] storeRefreshToken failed (code=${err.code}): ${err.message}`);
    throw ApiError.internal(`Failed to store refresh token: ${err.code} — ${err.message}`);
  }
};

const verifyAccessToken = (token) => {
  try {
    const decoded = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
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

const verifyRefreshToken = async (token) => {
  try {
    let decoded;
    try {
      decoded = jwt.verify(token, JWT_REFRESH_SECRET, { algorithms: ['HS256'] });
    } catch (e) {
      if (JWT_REFRESH_SECRET !== JWT_SECRET) {
        decoded = jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] });
      } else {
        throw e;
      }
    }
    if (decoded.type !== 'refresh') {
      throw ApiError.unauthorized('Invalid token type');
    }

    await ensureSchema();
    let result;

    if (_hasTokenHash) {
      const tokenHash = hashRefreshToken(token);
      result = await pool.query(
        `SELECT * FROM refresh_tokens
         WHERE is_revoked = FALSE AND expires_at > CURRENT_TIMESTAMP
           AND (
             (token_hash IS NOT NULL AND token_hash = $1)
             OR (token IS NOT NULL AND token = $2)
           )`,
        [tokenHash, token]
      );
    } else {
      result = await pool.query(
        `SELECT * FROM refresh_tokens
         WHERE token = $1 AND is_revoked = FALSE AND expires_at > CURRENT_TIMESTAMP`,
        [token]
      );
    }

    if (result.rows.length === 0) {
      throw ApiError.unauthorized('Refresh token is invalid or expired');
    }

    return { ...decoded, tokenId: result.rows[0].id };
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

const revokeRefreshToken = async (token) => {
  await ensureSchema();
  const tokenHash = hashRefreshToken(token);

  let result;
  if (_hasTokenHash) {
    result = await pool.query(
      `UPDATE refresh_tokens
       SET is_revoked = TRUE, revoked_at = CURRENT_TIMESTAMP
       WHERE is_revoked = FALSE
         AND ((token_hash IS NOT NULL AND token_hash = $1) OR (token IS NOT NULL AND token = $2))
       RETURNING id`,
      [tokenHash, token]
    );
  } else {
    result = await pool.query(
      `UPDATE refresh_tokens
       SET is_revoked = TRUE, revoked_at = CURRENT_TIMESTAMP
       WHERE token = $1 AND is_revoked = FALSE
       RETURNING id`,
      [token]
    );
  }

  if (result.rows.length === 0) {
    logger.warn(`revokeRefreshToken: token not found (already revoked or expired)`);
    return false;
  }
  logger.info(`Refresh token revoked: ${result.rows[0].id}`);
  return true;
};

const revokeAllUserTokens = async (userId) => {
  const result = await pool.query(
    `UPDATE refresh_tokens
     SET is_revoked = TRUE, revoked_at = CURRENT_TIMESTAMP
     WHERE user_id = $1 AND is_revoked = FALSE
     RETURNING id`,
    [userId]
  );
  logger.info(`Revoked ${result.rowCount} tokens for user: ${userId}`);
  return result.rowCount;
};

const cleanupExpiredTokens = async () => {
  try {
    const result = await pool.query(
      `DELETE FROM refresh_tokens
       WHERE expires_at < CURRENT_TIMESTAMP
          OR (is_revoked = TRUE AND revoked_at < CURRENT_TIMESTAMP - INTERVAL '7 days')`
    );
    if (result.rowCount > 0) {
      logger.info(`Cleaned up ${result.rowCount} expired/revoked refresh_token row(s)`);
    }
    return result.rowCount;
  } catch (error) {
    logger.error('Error cleaning up tokens:', error);
  }
};

const generateTokenPair = async (userId, role, deviceInfo = {}, ipAddress = null) => {
  const accessToken = generateAccessToken(userId, role);
  const refreshToken = generateRefreshToken(userId, role);
  await storeRefreshToken(userId, refreshToken, deviceInfo, ipAddress);
  return { accessToken, refreshToken };
};

module.exports = {
  ensureSchema,
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
