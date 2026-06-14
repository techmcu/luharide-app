const { pool, queryRead } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const { emitNotificationToUser } = require('../../socket/realtimeEmitter');

const adminEmail = process.env.ADMIN_EMAIL
  ? process.env.ADMIN_EMAIL.toLowerCase().trim()
  : null;

function ensurePlatformAdmin(user) {
  const email = user?.email ? String(user.email).toLowerCase().trim() : null;
  if (!adminEmail || !email || email !== adminEmail) {
    throw ApiError.forbidden('Only platform admin can perform this action');
  }
}

// ---------------------------------------------------------------------------
// POST /api/platform-admin/notifications/bulk  { segment, title, body }
// ---------------------------------------------------------------------------
const sendBulkNotification = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { segment, title, body } = req.body || {};

  if (!title || !body) throw ApiError.badRequest('title and body are required');
  if (title.length > 50) throw ApiError.badRequest('Title max 50 characters (longer text gets cut off in push notifications)');
  if (body.length > 150) throw ApiError.badRequest('Body max 150 characters (longer text gets cut off in push notifications)');
  const validSegments = ['all', 'passenger', 'driver', 'drivers', 'union_admin', 'union_admins'];
  if (!segment || !validSegments.includes(segment)) {
    throw ApiError.badRequest(`segment must be one of: all, passenger, driver, union_admin`);
  }

  const dupCheck = await pool.query(
    `SELECT id FROM broadcasts
     WHERE title = $1 AND body = $2 AND created_at > NOW() - INTERVAL '1 hour'
     LIMIT 1`,
    [title, body]
  );
  if (dupCheck.rows.length > 0) {
    throw ApiError.badRequest('This exact notification was already sent within the last hour. Sending duplicates annoys users.');
  }

  const roleFilter = segment === 'all' ? null
    : (segment === 'driver' || segment === 'drivers') ? 'driver'
    : (segment === 'union_admin' || segment === 'union_admins') ? 'union_admin'
    : 'passenger';

  const countSql = roleFilter
    ? `SELECT COUNT(*)::int AS total FROM users WHERE role = $1 AND is_active = true`
    : `SELECT COUNT(*)::int AS total FROM users WHERE is_active = true`;
  const countParams = roleFilter ? [roleFilter] : [];
  const countRes = await pool.query(countSql, countParams);
  const userCount = countRes.rows[0]?.total || 0;

  if (userCount === 0) throw ApiError.badRequest('No active users in this segment');
  if (userCount > 10000) throw ApiError.badRequest(`Segment has ${userCount} users — contact dev team for large broadcasts`);

  const insertSql = roleFilter
    ? `INSERT INTO notifications (user_id, type, title, body)
       SELECT id, 'admin_broadcast', $1, $2 FROM users WHERE role = $3 AND is_active = true
       RETURNING id, user_id`
    : `INSERT INTO notifications (user_id, type, title, body)
       SELECT id, 'admin_broadcast', $1, $2 FROM users WHERE is_active = true
       RETURNING id, user_id`;

  const params = roleFilter ? [title, body, roleFilter] : [title, body];
  const result = await pool.query(insertSql, params);

  for (const row of result.rows) {
    try { emitNotificationToUser(row.user_id, { ...row, type: 'admin_broadcast', title, body, is_read: false }); } catch (_) {}
  }

  await pool.query(
    `INSERT INTO broadcasts (admin_id, segment, title, body, sent_count) VALUES ($1,$2,$3,$4,$5)`,
    [req.user.id, segment, title, body, result.rowCount]
  );

  logger.info(`Platform admin ${req.user.id} sent broadcast to ${segment}: ${result.rowCount} users`);
  ApiResponse.success({ sentCount: result.rowCount, segment }, 'Notification sent').send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/notifications/history?page=1&limit=20
// ---------------------------------------------------------------------------
const getBroadcastHistory = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(10, Math.max(1, parseInt(req.query.limit, 10) || 10));
  const offset = (page - 1) * limit;

  const countRes = await queryRead('SELECT COUNT(*)::int AS total FROM broadcasts');
  const rows = await queryRead(
    `SELECT b.id, b.segment, b.title, b.body, b.sent_count, b.created_at,
            u.name AS admin_name
     FROM broadcasts b LEFT JOIN users u ON b.admin_id = u.id
     ORDER BY b.created_at DESC LIMIT $1 OFFSET $2`,
    [limit, offset]
  );

  ApiResponse.success({
    broadcasts: rows.rows,
    total: countRes.rows[0].total,
    page,
    totalPages: Math.ceil(countRes.rows[0].total / limit),
  }, 'Broadcast history').send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/union-fcm
// ---------------------------------------------------------------------------
const getUnionFcmSettings = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const globalRes = await queryRead(
    `SELECT value FROM settings WHERE key = 'fcm_global_union_rides'`
  );
  const globalEnabled = (globalRes.rows[0]?.value ?? 'true') === 'true';

  const unionsRes = await queryRead(
    `SELECT id, name, fcm_enabled, status
     FROM unions
     WHERE status = 'approved'
     ORDER BY name ASC`
  );

  ApiResponse.success({
    globalEnabled,
    unions: unionsRes.rows,
  }, 'Union FCM settings').send(res);
});

// ---------------------------------------------------------------------------
// PATCH /api/platform-admin/union-fcm/global  { enabled: true/false }
// ---------------------------------------------------------------------------
const toggleGlobalUnionFcm = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { enabled } = req.body || {};
  if (typeof enabled !== 'boolean') {
    throw ApiError.badRequest('enabled must be true or false');
  }

  await pool.query(
    `INSERT INTO settings (key, value, description, updated_at)
     VALUES ('fcm_global_union_rides', $1, 'Global on/off for FCM push when unions create rides', NOW())
     ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = NOW()`,
    [String(enabled)]
  );

  await pool.query(
    `UPDATE unions SET fcm_enabled = $1 WHERE status = 'approved'`,
    [enabled]
  );

  const unionsRes = await pool.query(
    `SELECT id, name, fcm_enabled, status FROM unions WHERE status = 'approved' ORDER BY name ASC`
  );

  logger.info(`Platform admin ${req.user.id} set global union FCM to ${enabled} (all ${unionsRes.rowCount} unions updated)`);
  ApiResponse.success({ globalEnabled: enabled, unions: unionsRes.rows }, 'Global FCM setting updated').send(res);
});

// ---------------------------------------------------------------------------
// PATCH /api/platform-admin/union-fcm/:unionId  { enabled: true/false }
// ---------------------------------------------------------------------------
const toggleUnionFcm = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { unionId } = req.params;
  const { enabled } = req.body || {};
  if (typeof enabled !== 'boolean') {
    throw ApiError.badRequest('enabled must be true or false');
  }

  const result = await pool.query(
    `UPDATE unions SET fcm_enabled = $1 WHERE id = $2 AND status = 'approved' RETURNING id, name, fcm_enabled`,
    [enabled, unionId]
  );
  if (result.rowCount === 0) {
    throw ApiError.notFound('Union not found or not approved');
  }

  logger.info(`Platform admin ${req.user.id} set FCM for union ${unionId} to ${enabled}`);
  ApiResponse.success(result.rows[0], 'Union FCM setting updated').send(res);
});

module.exports = {
  sendBulkNotification,
  getBroadcastHistory,
  getUnionFcmSettings,
  toggleGlobalUnionFcm,
  toggleUnionFcm,
};
