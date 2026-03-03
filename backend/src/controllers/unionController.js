const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

/**
 * Register a new union for the current user.
 * POST /api/union/register
 */
const registerUnion = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const { name, location, contact_phone, contact_email } = req.body;

  if (!name || String(name).trim().length < 3) {
    throw ApiError.badRequest('Union name must be at least 3 characters');
  }

  // Basic: ensure user does not already have a union
  const existing = await pool.query(
    `SELECT u.*
     FROM unions u
     JOIN union_admins ua ON ua.union_id = u.id
     WHERE ua.user_id = $1`,
    [userId]
  );
  if (existing.rows.length > 0) {
    throw ApiError.badRequest('You already manage a taxi union');
  }

  const insertRes = await pool.query(
    `INSERT INTO unions (name, address, contact_phone, contact_email, is_active)
     VALUES ($1, $2, $3, $4, TRUE)
     RETURNING *`,
    [String(name).trim(), location || null, contact_phone || null, contact_email || null]
  );

  const union = insertRes.rows[0];

  await pool.query(
    `INSERT INTO union_admins (union_id, user_id)
     VALUES ($1, $2)
     ON CONFLICT (union_id, user_id) DO NOTHING`,
    [union.id, userId]
  );

  // For now, mark this user as union_admin role if not already
  await pool.query(
    `UPDATE users SET role = 'union_admin'
     WHERE id = $1 AND role <> 'union_admin'`,
    [userId]
  );

  logger.info(`Union registered ${union.id} by user ${userId}`);

  ApiResponse.created(
    { union },
    'Union registered successfully'
  ).send(res);
});

module.exports = {
  registerUnion,
};

