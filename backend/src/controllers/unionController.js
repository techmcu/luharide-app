const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

const adminEmail = process.env.ADMIN_EMAIL
  ? process.env.ADMIN_EMAIL.toLowerCase().trim()
  : null;

function ensurePlatformAdmin(user) {
  const email = user?.email ? String(user.email).toLowerCase().trim() : null;
  if (!adminEmail || !email || email !== adminEmail) {
    throw ApiError.forbidden('Only app admin can perform this action');
  }
}

/**
 * Get current user's union + status.
 * GET /api/union/me
 */
const getMyUnion = asyncHandler(async (req, res) => {
  const userId = req.user.id;

  const result = await pool.query(
    `SELECT u.*
     FROM unions u
     JOIN union_admins ua ON ua.union_id = u.id
     WHERE ua.user_id = $1
     ORDER BY u.created_at DESC
     LIMIT 1`,
    [userId]
  );

  const union = result.rows[0] || null;
  const status = union?.status || 'none';

  ApiResponse.success(
    { union, status },
    'Union status retrieved'
  ).send(res);
});

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

  // Basic: ensure user does not already have a union request
  const existing = await pool.query(
    `SELECT u.*
     FROM unions u
     JOIN union_admins ua ON ua.union_id = u.id
     WHERE ua.user_id = $1`,
    [userId]
  );
  if (existing.rows.length > 0) {
    throw ApiError.badRequest('You already manage or requested a taxi union');
  }

  const insertRes = await pool.query(
    `INSERT INTO unions (name, address, contact_phone, contact_email, is_active, status)
     VALUES ($1, $2, $3, $4, FALSE, 'pending')
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

  logger.info(`Union registration requested ${union.id} by user ${userId}`);

  ApiResponse.created(
    { union },
    'Union registration submitted. Admin will review your request.'
  ).send(res);
});

/**
 * List unions by status (platform admin only).
 * GET /api/union/admin/unions?status=pending
 */
const listUnions = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { status } = req.query;

  let query = 'SELECT * FROM unions';
  const params = [];
  if (status) {
    query += ' WHERE status = $1';
    params.push(status);
  }
  query += ' ORDER BY created_at DESC';

  const result = await pool.query(query, params);
  ApiResponse.success(
    { unions: result.rows, count: result.rows.length },
    'Unions retrieved'
  ).send(res);
});

/**
 * Approve union (platform admin only).
 * POST /api/union/admin/unions/:id/approve
 */
const approveUnion = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;

  const unionRes = await pool.query(
    'SELECT * FROM unions WHERE id = $1',
    [id]
  );
  if (unionRes.rows.length === 0) {
    throw ApiError.notFound('Union not found');
  }

  await pool.query(
    `UPDATE unions
     SET status = 'approved', is_active = TRUE, updated_at = NOW()
     WHERE id = $1`,
    [id]
  );

  // Promote all admins for this union to union_admin role
  await pool.query(
    `UPDATE users
     SET role = 'union_admin'
     WHERE id IN (SELECT user_id FROM union_admins WHERE union_id = $1)
       AND role <> 'union_admin'`,
    [id]
  );

  logger.info(`Union approved ${id} by platform admin ${req.user.id}`);

  ApiResponse.success(
    { id, status: 'approved' },
    'Union approved successfully'
  ).send(res);
});

/**
 * Reject union (platform admin only).
 * POST /api/union/admin/unions/:id/reject
 */
const rejectUnion = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;

  const unionRes = await pool.query(
    'SELECT * FROM unions WHERE id = $1',
    [id]
  );
  if (unionRes.rows.length === 0) {
    throw ApiError.notFound('Union not found');
  }

  await pool.query(
    `UPDATE unions
     SET status = 'rejected', is_active = FALSE, updated_at = NOW()
     WHERE id = $1`,
    [id]
  );

  logger.info(`Union rejected ${id} by platform admin ${req.user.id}`);

  ApiResponse.success(
    { id, status: 'rejected' },
    'Union rejected'
  ).send(res);
});

/**
 * For a union admin (approved), list their drivers.
 * GET /api/union/drivers
 */
const getUnionDrivers = asyncHandler(async (req, res) => {
  // Find union for this admin
  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }

  const unionId = resUnion.rows[0].union_id;
  const driversRes = await pool.query(
    `SELECT id, name, vehicle_number, phone, whatsapp_number, profile_image_url, created_at
     FROM union_drivers
     WHERE union_id = $1
     ORDER BY created_at DESC`,
    [unionId]
  );

  ApiResponse.success(
    { drivers: driversRes.rows, count: driversRes.rows.length },
    'Union drivers retrieved'
  ).send(res);
});

module.exports = {
  getMyUnion,
  registerUnion,
  listUnions,
  approveUnion,
  rejectUnion,
  getUnionDrivers,
};


