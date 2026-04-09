const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { emitNotificationToUser } = require('../socket/realtimeEmitter');

function clampDays(days) {
  const n = parseInt(days, 10);
  if (Number.isNaN(n) || n < 1) return 1;
  if (n > 30) return 30;
  return n;
}

function deadlineFromNowDays(days) {
  const ms = clampDays(days) * 24 * 60 * 60 * 1000;
  return new Date(Date.now() + ms).toISOString();
}

async function notifyUser(userId, type, title, body, data = null) {
  const n = await pool.query(
    `INSERT INTO notifications (user_id, type, title, body, data)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING id, user_id, type, title, body, data, created_at, is_read`,
    [userId, type, title, body, data]
  );
  if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
  return n.rows[0] || null;
}

/**
 * Admin: revoke driver blue-tick and open a 1-time re-upload window.
 * POST /api/admin/kyc/drivers/:userId/reverify
 * Body: { message?: string, days?: number }
 *
 * Rule: same user can be granted at most once per day.
 */
const grantDriverReverify = asyncHandler(async (req, res) => {
  const { userId } = req.params;
  const { message, days } = req.body || {};
  const adminId = req.user.id;

  const u = await pool.query(
    `SELECT id, name, driver_verification_status, driver_kyc_reupload_granted_on
     FROM users WHERE id = $1`,
    [userId]
  );
  const user = u.rows[0];
  if (!user) throw ApiError.notFound('User not found');

  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const last = user.driver_kyc_reupload_granted_on
    ? new Date(user.driver_kyc_reupload_granted_on).toISOString().slice(0, 10)
    : null;
  if (last === today) {
    throw ApiError.badRequest('Re-upload permission already granted today for this user');
  }

  const deadlineIso = deadlineFromNowDays(days ?? 7);
  await pool.query(
    `UPDATE users
     SET driver_verification_status = 'needs_reverify',
         driver_kyc_reupload_allowed = TRUE,
         driver_kyc_reupload_granted_on = CURRENT_DATE,
         driver_kyc_reupload_deadline = $2,
         updated_at = NOW()
     WHERE id = $1`,
    [userId, deadlineIso]
  );

  const body =
    (message && String(message).trim()) ||
    'Your documents need re-verification. Please upload updated documents in the app.';
  await notifyUser(
    userId,
    'kyc_reverify_required',
    'Re-verify documents',
    body,
    { scope: 'driver', deadline: deadlineIso }
  );

  logger.info(`Admin ${adminId} granted driver reverify for user ${userId} until ${deadlineIso}`);
  ApiResponse.success(
    { userId, scope: 'driver', deadline: deadlineIso },
    'Re-upload enabled for driver'
  ).send(res);
});

/**
 * Admin: revoke union documents blue-tick and open a 1-time re-upload window.
 * POST /api/admin/kyc/unions/:unionId/reverify
 * Body: { message?: string, days?: number }
 *
 * Rule: same union can be granted at most once per day.
 */
const grantUnionReverify = asyncHandler(async (req, res) => {
  const { unionId } = req.params;
  const { message, days } = req.body || {};
  const adminId = req.user.id;

  const u = await pool.query(
    `SELECT id, name, documents_reupload_granted_on
     FROM unions WHERE id = $1`,
    [unionId]
  );
  const union = u.rows[0];
  if (!union) throw ApiError.notFound('Union not found');

  const today = new Date().toISOString().slice(0, 10);
  const last = union.documents_reupload_granted_on
    ? new Date(union.documents_reupload_granted_on).toISOString().slice(0, 10)
    : null;
  if (last === today) {
    throw ApiError.badRequest('Re-upload permission already granted today for this union');
  }

  const deadlineIso = deadlineFromNowDays(days ?? 7);
  await pool.query(
    `UPDATE unions
     SET documents_status = 'needs_reverify',
         documents_reupload_allowed = TRUE,
         documents_reupload_granted_on = CURRENT_DATE,
         documents_reupload_deadline = $2,
         updated_at = NOW()
     WHERE id = $1`,
    [unionId, deadlineIso]
  );

  // Notify all union admins linked to this union.
  const admins = await pool.query(
    `SELECT ua.user_id
     FROM union_admins ua
     WHERE ua.union_id = $1`,
    [unionId]
  );
  const body =
    (message && String(message).trim()) ||
    'Your union documents need re-verification. Please upload updated documents in the app.';
  for (const row of admins.rows) {
    // best-effort
    try {
      await notifyUser(
        row.user_id,
        'kyc_reverify_required',
        'Re-verify union documents',
        body,
        { scope: 'union', unionId, deadline: deadlineIso }
      );
    } catch (e) {
      logger.warn(`Union reverify notify failed for user ${row.user_id}: ${e.message}`);
    }
  }

  logger.info(`Admin ${adminId} granted union reverify for union ${unionId} until ${deadlineIso}`);
  ApiResponse.success(
    { unionId, scope: 'union', deadline: deadlineIso },
    'Re-upload enabled for union'
  ).send(res);
});

/**
 * Admin: list unions whose documents were updated and are pending review.
 * GET /api/admin/union-doc-requests?status=pending
 */
const listPendingUnionDocRequests = asyncHandler(async (req, res) => {
  const status = String(req.query.status || 'pending').toLowerCase();
  if (status !== 'pending') throw ApiError.badRequest('Only status=pending supported');

  const result = await pool.query(
    `SELECT
       u.*,
       ua.user_id AS registrar_user_id,
       usr.name   AS applicant_name,
       usr.email  AS applicant_email,
       usr.phone  AS applicant_phone
     FROM unions u
     LEFT JOIN union_admins ua ON ua.union_id = u.id
     LEFT JOIN users usr ON usr.id = ua.user_id
     WHERE u.status = 'approved' AND u.documents_status = 'pending'
     ORDER BY u.updated_at DESC NULLS LAST, u.created_at DESC`
  );

  ApiResponse.success(
    { requests: result.rows },
    'Pending union document requests retrieved'
  ).send(res);
});

/**
 * Admin: approve union document update (sets documents_status=approved).
 * POST /api/admin/union-doc-requests/:id/approve
 */
const approveUnionDocRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  await pool.query(
    `UPDATE unions
     SET documents_status = 'approved',
         documents_reupload_allowed = FALSE,
         documents_reupload_deadline = NULL,
         updated_at = NOW()
     WHERE id = $1`,
    [id]
  );
  ApiResponse.success({ id, status: 'approved' }, 'Union documents approved').send(res);
});

/**
 * Admin: reject union document update (sets documents_status=needs_reverify and re-opens reupload).
 * POST /api/admin/union-doc-requests/:id/reject
 */
const rejectUnionDocRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const { reason, days } = req.body || {};
  const deadlineIso = deadlineFromNowDays(days ?? 7);

  await pool.query(
    `UPDATE unions
     SET documents_status = 'needs_reverify',
         documents_reupload_allowed = TRUE,
         documents_reupload_granted_on = CURRENT_DATE,
         documents_reupload_deadline = $2,
         updated_at = NOW()
     WHERE id = $1`,
    [id, deadlineIso]
  );

  const admins = await pool.query(
    `SELECT ua.user_id
     FROM union_admins ua
     WHERE ua.union_id = $1`,
    [id]
  );
  const body =
    (reason && String(reason).trim()) ||
    'Your union document update was rejected. Please upload correct documents again.';
  for (const row of admins.rows) {
    try {
      await notifyUser(
        row.user_id,
        'kyc_reverify_required',
        'Union documents need update',
        body,
        { scope: 'union', unionId: id, deadline: deadlineIso }
      );
    } catch (e) {
      logger.warn(`Union doc reject notify failed for user ${row.user_id}: ${e.message}`);
    }
  }

  ApiResponse.success({ id, status: 'needs_reverify' }, 'Union documents rejected').send(res);
});

module.exports = {
  grantDriverReverify,
  grantUnionReverify,
  listPendingUnionDocRequests,
  approveUnionDocRequest,
  rejectUnionDocRequest,
};

