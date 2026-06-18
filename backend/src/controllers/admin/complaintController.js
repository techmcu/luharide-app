const { pool, queryRead } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const {
  invalidateRideLimitsCache,
  DAILY_KEY: RIDE_DAILY_KEY,
  WEEKLY_KEY: RIDE_WEEKLY_KEY,
  MIN_LIMIT: RIDE_MIN_LIMIT,
  MAX_LIMIT: RIDE_MAX_LIMIT,
} = require('../../services/rideLimitSettings');

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
// GET /api/platform-admin/complaints?status=&search=&page=1&limit=20
// ---------------------------------------------------------------------------
const getComplaints = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const status = (req.query.status || '').trim().toLowerCase();
  const search = (req.query.search || '').trim();
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 20));
  const offset = (page - 1) * limit;

  const conditions = [];
  const params = [];
  let idx = 1;

  if (status === 'open' || status === 'resolved') {
    conditions.push(`c.status = $${idx}`);
    params.push(status);
    idx++;
  }
  if (search) {
    conditions.push(`(c.subject ILIKE $${idx} OR u.name ILIKE $${idx})`);
    params.push(`%${search}%`);
    idx++;
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  const countRes = await queryRead(
    `SELECT COUNT(*)::int AS total FROM complaints c JOIN users u ON c.user_id = u.id ${where}`,
    params
  );

  const rows = await queryRead(
    `SELECT c.*, u.name AS user_name, u.phone AS user_phone, u.role AS user_role
     FROM complaints c JOIN users u ON c.user_id = u.id
     ${where}
     ORDER BY CASE WHEN c.status = 'open' THEN 0 ELSE 1 END, c.created_at DESC
     LIMIT $${idx} OFFSET $${idx + 1}`,
    [...params, limit, offset]
  );

  ApiResponse.success({
    complaints: rows.rows,
    total: countRes.rows[0].total,
    page,
    totalPages: Math.ceil(countRes.rows[0].total / limit),
  }, 'Complaints list').send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/complaints/:id
// ---------------------------------------------------------------------------
const getComplaintDetail = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;

  const result = await queryRead(
    `SELECT c.*, u.name AS user_name, u.phone AS user_phone, u.email AS user_email, u.role AS user_role,
            r.name AS resolved_by_name
     FROM complaints c
     JOIN users u ON c.user_id = u.id
     LEFT JOIN users r ON c.resolved_by = r.id
     WHERE c.id = $1`,
    [id]
  );
  if (result.rows.length === 0) throw ApiError.notFound('Complaint not found');

  ApiResponse.success({ complaint: result.rows[0] }, 'Complaint detail').send(res);
});

// ---------------------------------------------------------------------------
// POST /api/platform-admin/complaints/:id/resolve  { resolution_note }
// ---------------------------------------------------------------------------
const resolveComplaint = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;
  const { resolution_note } = req.body || {};
  if (resolution_note && resolution_note.length > 2000) throw ApiError.badRequest('Resolution note must be under 2000 characters');

  const result = await pool.query(
    `UPDATE complaints SET status = 'resolved', resolution_note = $1,
            resolved_by = $2, resolved_at = NOW()
     WHERE id = $3 AND status = 'open'
     RETURNING id, status, user_id`,
    [resolution_note || null, req.user.id, id]
  );
  if (result.rows.length === 0) throw ApiError.notFound('Complaint not found or already resolved');

  const row = result.rows[0];
  await pool.query(
    `INSERT INTO notifications (user_id, type, title, body)
     VALUES ($1, 'complaint_resolved', 'Complaint resolved', $2)`,
    [row.user_id, resolution_note || 'Your complaint has been resolved.']
  );

  logger.info(`Platform admin ${req.user.id} resolved complaint ${id}`);
  ApiResponse.success(result.rows[0], 'Complaint resolved').send(res);
});

// ---------------------------------------------------------------------------
// User-facing: POST /api/platform-admin/complaints/submit  { subject, body }
// ---------------------------------------------------------------------------
const submitComplaint = asyncHandler(async (req, res) => {
  const { subject, body } = req.body || {};
  if (!subject || !body) throw ApiError.badRequest('subject and body are required');
  if (subject.length > 200) throw ApiError.badRequest('subject must be under 200 characters');
  if (body.length > 2000) throw ApiError.badRequest('body must be under 2000 characters');

  const result = await pool.query(
    `INSERT INTO complaints (user_id, subject, body) VALUES ($1, $2, $3) RETURNING id, status, created_at`,
    [req.user.id, subject, body]
  );

  ApiResponse.created(result.rows[0], 'Complaint submitted').send(res);
});

// ---------------------------------------------------------------------------
// User-facing: GET /api/platform-admin/complaints/mine
// ---------------------------------------------------------------------------
const getMyComplaints = asyncHandler(async (req, res) => {
  const result = await queryRead(
    `SELECT id, subject, body, status, resolution_note, created_at, resolved_at
     FROM complaints WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20`,
    [req.user.id]
  );

  ApiResponse.success({ complaints: result.rows }, 'My complaints').send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/config
// ---------------------------------------------------------------------------
const getAppConfig = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const result = await queryRead(
    `SELECT key, value, description FROM settings
     WHERE key IN ('platform_commission_driver','platform_commission_passenger',
                   '${RIDE_DAILY_KEY}','${RIDE_WEEKLY_KEY}')`
  );

  const config = {};
  for (const row of result.rows) {
    config[row.key] = row.value;
  }

  ApiResponse.success({ config }, 'App config').send(res);
});

// ---------------------------------------------------------------------------
// PATCH /api/platform-admin/config  { key: value, ... }
// ---------------------------------------------------------------------------
const updateAppConfig = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const updates = req.body || {};

  const allowedKeys = [
    'platform_commission_driver', 'platform_commission_passenger',
    RIDE_DAILY_KEY, RIDE_WEEKLY_KEY,
  ];

  // Pass 1 — validate EVERYTHING first. Nothing is written unless all values
  // are valid, so a bad value can never leave a half-applied config.
  const pending = [];
  let rideLimitChanged = false;
  for (const [key, value] of Object.entries(updates)) {
    if (!allowedKeys.includes(key)) continue;
    const strVal = String(value).trim();

    if (key === 'platform_commission_driver' || key === 'platform_commission_passenger') {
      const num = parseFloat(strVal);
      if (isNaN(num) || num < 0 || num > 100) {
        throw ApiError.badRequest(`${key} must be a number between 0 and 100`);
      }
    }

    if (key === RIDE_DAILY_KEY || key === RIDE_WEEKLY_KEY) {
      // Whole numbers only — reject floats, text, emojis, negatives, blanks.
      if (!/^\d+$/.test(strVal)) {
        throw ApiError.badRequest(
          `${key} must be a whole number between ${RIDE_MIN_LIMIT} and ${RIDE_MAX_LIMIT} (0 disables independent rides)`
        );
      }
      const num = Number(strVal);
      if (!Number.isInteger(num) || num < RIDE_MIN_LIMIT || num > RIDE_MAX_LIMIT) {
        throw ApiError.badRequest(
          `${key} must be a whole number between ${RIDE_MIN_LIMIT} and ${RIDE_MAX_LIMIT}`
        );
      }
      rideLimitChanged = true;
    }

    pending.push({ key, strVal });
  }

  // Pass 2 — all valid, now persist.
  const applied = [];
  for (const { key, strVal } of pending) {
    await pool.query(
      `INSERT INTO settings (key, value, updated_at) VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      [key, strVal]
    );
    applied.push(key);
  }

  if (rideLimitChanged) invalidateRideLimitsCache();

  logger.info(`Platform admin ${req.user.id} updated config: ${applied.join(', ')}`);
  ApiResponse.success({ updated: applied }, 'Config updated').send(res);
});

module.exports = {
  getComplaints,
  getComplaintDetail,
  resolveComplaint,
  submitComplaint,
  getMyComplaints,
  getAppConfig,
  updateAppConfig,
};
