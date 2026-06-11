const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { emitNotificationToUser } = require('../socket/realtimeEmitter');

/** Default in-app copy (EN + HI) when admin does not pass a custom `message` body. */
const DRIVER_REVERIFY_TITLE = 'Documents need re-verification';
const DRIVER_REVERIFY_BODY =
  'Your verified badge has been removed. Open Profile → Driver verification, upload updated documents, and submit for review. The badge returns after admin approval.';

const UNION_REVERIFY_TITLE = 'Union documents need re-verification';
const UNION_REVERIFY_BODY =
  'Your union verified status has been reset. Open Union documents in the app, upload updated files, and save. The badge returns after admin approval.';

const UNION_DOC_REJECT_TITLE = 'Union documents need an update';
const UNION_DOC_REJECT_BODY =
  'Your recent document update could not be approved. Please upload correct documents under Union documents and submit again.';

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
 * Single INSERT for all union admins (avoids N notification round-trips).
 */
async function notifyUnionAdmins(unionId, type, title, body, data = null) {
  const result = await pool.query(
    `INSERT INTO notifications (user_id, type, title, body, data)
     SELECT ua.user_id, $2, $3, $4, $5
     FROM union_admins ua
     WHERE ua.union_id = $1
     RETURNING id, user_id, type, title, body, data, created_at, is_read`,
    [unionId, type, title, body, data]
  );
  for (const row of result.rows) {
    try {
      emitNotificationToUser(row.user_id, row);
    } catch (e) {
      logger.warn(`emit notification failed for user ${row.user_id}: ${e.message}`);
    }
  }
  return result.rows;
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

  const today = new Date().toISOString().slice(0, 10);
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

  const custom = message && String(message).trim();
  const body = custom || DRIVER_REVERIFY_BODY;
  await notifyUser(userId, 'kyc_reverify_required', DRIVER_REVERIFY_TITLE, body, {
    scope: 'driver',
    deadline: deadlineIso,
  });

  logger.info(`Admin ${adminId} granted driver reverify for user ${userId} until ${deadlineIso}`);
  ApiResponse.success(
    { userId, scope: 'driver', deadline: deadlineIso },
    'Re-upload enabled for driver'
  ).send(res);
});

/**
 * Admin: revoke union documents blue-tick and open a 1-time re-upload window.
 * POST /api/admin/kyc/unions/:unionId/reverify
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

  const custom = message && String(message).trim();
  const body = custom || UNION_REVERIFY_BODY;
  await notifyUnionAdmins(unionId, 'kyc_reverify_required', UNION_REVERIFY_TITLE, body, {
    scope: 'union',
    unionId,
    deadline: deadlineIso,
  });

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

  // Primary DB: admins must see new union doc submissions immediately (no replica lag).
  const result = await pool.query(
    `SELECT * FROM (
       SELECT DISTINCT ON (u.id)
         u.*,
         ua.user_id AS registrar_user_id,
         usr.name   AS applicant_name,
         usr.email  AS applicant_email,
         usr.phone  AS applicant_phone
       FROM unions u
       LEFT JOIN union_admins ua ON ua.union_id = u.id
       LEFT JOIN users usr ON usr.id = ua.user_id
       WHERE u.status = 'approved' AND u.documents_status = 'pending'
       ORDER BY u.id, u.updated_at DESC NULLS LAST, u.created_at DESC, ua.user_id NULLS LAST
     ) q
     ORDER BY q.updated_at DESC NULLS LAST, q.created_at DESC`
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
  const result = await pool.query(
    `UPDATE unions
     SET documents_status = 'approved',
         documents_reupload_allowed = FALSE,
         documents_reupload_deadline = NULL,
         updated_at = NOW()
     WHERE id = $1 AND status = 'approved' AND documents_status = 'pending'
     RETURNING id`,
    [id]
  );
  if (result.rowCount === 0) {
    throw ApiError.notFound('No pending document request for this union');
  }

  const title = 'Union documents approved';
  const body =
    'Your updated union documents have been approved. Re-upload is closed until admin requests again.';
  await notifyUnionAdmins(id, 'union_documents_approved', title, body, {
    scope: 'union',
    unionId: id,
  });

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

  const updated = await pool.query(
    `UPDATE unions
     SET documents_status = 'needs_reverify',
         documents_reupload_allowed = TRUE,
         documents_reupload_granted_on = CURRENT_DATE,
         documents_reupload_deadline = $2,
         updated_at = NOW()
     WHERE id = $1 AND status = 'approved' AND documents_status = 'pending'
     RETURNING id`,
    [id, deadlineIso]
  );
  if (updated.rowCount === 0) {
    throw ApiError.notFound('No pending document request for this union');
  }

  const custom = reason && String(reason).trim();
  const body = custom || UNION_DOC_REJECT_BODY;
  await notifyUnionAdmins(id, 'kyc_reverify_required', UNION_DOC_REJECT_TITLE, body, {
    scope: 'union',
    unionId: id,
    deadline: deadlineIso,
  });

  ApiResponse.success({ id, status: 'needs_reverify' }, 'Union documents rejected').send(res);
});

module.exports = {
  grantDriverReverify,
  grantUnionReverify,
  listPendingUnionDocRequests,
  approveUnionDocRequest,
  rejectUnionDocRequest,
};
