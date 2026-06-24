const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const userCache = require('../../utils/userCache');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const {
  ensurePlatformAdmin,
  demoteUnionAdminsOrphanedByReject,
  unlinkUnionAdminsForRejectedUnion,
} = require('./unionHelpers');

const getPendingUnionRequests = asyncHandler(async (req, res) => {
  const result = await pool.query(
    `SELECT * FROM (
       SELECT
         u.*,
         ua.user_id AS registrar_user_id,
         usr.name   AS applicant_name,
         usr.email  AS applicant_email,
         usr.phone  AS applicant_phone,
         ROW_NUMBER() OVER (
           PARTITION BY u.id
           ORDER BY ua.user_id ASC NULLS LAST
         ) AS _rn
       FROM unions u
       LEFT JOIN union_admins ua ON ua.union_id = u.id
       LEFT JOIN users usr ON usr.id = ua.user_id
       WHERE u.status = 'pending'
     ) sub
     WHERE sub._rn = 1
     ORDER BY sub.created_at ASC`
  );

  const requests = result.rows.map(({ _rn, ...row }) => row);

  ApiResponse.success(
    { requests },
    'Pending union requests retrieved'
  ).send(res);
});

const approveUnionRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const unionRes = await client.query(
      'SELECT * FROM unions WHERE id = $1 AND status = $2 FOR UPDATE',
      [id, 'pending']
    );
    if (unionRes.rows.length === 0) {
      throw ApiError.notFound('Pending union not found');
    }

    await client.query(
      `UPDATE unions
       SET status = 'approved',
           is_active = TRUE,
           documents_status = 'approved',
           documents_reupload_allowed = FALSE,
           documents_reupload_deadline = NULL,
           updated_at = NOW()
       WHERE id = $1`,
      [id]
    );

    const roleUpd = await client.query(
      `UPDATE users
       SET role = 'union_admin'
       WHERE id IN (SELECT user_id FROM union_admins WHERE union_id = $1)
         AND role <> 'union_admin'
       RETURNING id`,
      [id]
    );

    await client.query('COMMIT');

    // The just-promoted admin must see their new role IMMEDIATELY — drop the
    // 60s userCache entry, else authorize('union_admin') reads the stale cached
    // role and returns "Access denied" until the cache expires.
    for (const u of roleUpd.rows) userCache.invalidate(u.id);

    logger.info(`Union approved from admin panel ${id} by user ${req.user.id}`);

    ApiResponse.success(
      { id, status: 'approved' },
      'Union approved successfully'
    ).send(res);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

const rejectUnionRequest = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const unionRes = await client.query(
      'SELECT * FROM unions WHERE id = $1 AND status = $2 FOR UPDATE',
      [id, 'pending']
    );
    if (unionRes.rows.length === 0) {
      throw ApiError.notFound('Pending union not found');
    }

    await client.query(
      `UPDATE unions
       SET status = 'rejected',
           is_active = FALSE,
           documents_status = 'rejected',
           documents_reupload_allowed = FALSE,
           documents_reupload_deadline = NULL,
           updated_at = NOW()
       WHERE id = $1`,
      [id]
    );

    await demoteUnionAdminsOrphanedByReject(id, client);
    await unlinkUnionAdminsForRejectedUnion(id, client);

    await client.query('COMMIT');

    logger.info(`Union rejected from admin panel ${id} by user ${req.user.id}`);

    ApiResponse.success(
      { id, status: 'rejected' },
      'Union rejected'
    ).send(res);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

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
     SET status = 'approved',
         is_active = TRUE,
         documents_status = 'approved',
         documents_reupload_allowed = FALSE,
         documents_reupload_deadline = NULL,
         updated_at = NOW()
     WHERE id = $1`,
    [id]
  );

  const roleUpd = await pool.query(
    `UPDATE users
     SET role = 'union_admin'
     WHERE id IN (SELECT user_id FROM union_admins WHERE union_id = $1)
       AND role <> 'union_admin'
     RETURNING id`,
    [id]
  );

  // Fresh role visible immediately (see note above) — invalidate the cache.
  for (const u of roleUpd.rows) userCache.invalidate(u.id);

  logger.info(`Union approved ${id} by platform admin ${req.user.id}`);

  ApiResponse.success(
    { id, status: 'approved' },
    'Union approved successfully'
  ).send(res);
});

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
     SET status = 'rejected',
         is_active = FALSE,
         documents_status = 'rejected',
         documents_reupload_allowed = FALSE,
         documents_reupload_deadline = NULL,
         updated_at = NOW()
     WHERE id = $1`,
    [id]
  );

  await demoteUnionAdminsOrphanedByReject(id);
  await unlinkUnionAdminsForRejectedUnion(id);

  logger.info(`Union rejected ${id} by platform admin ${req.user.id}`);

  ApiResponse.success(
    { id, status: 'rejected' },
    'Union rejected'
  ).send(res);
});

module.exports = {
  getPendingUnionRequests,
  approveUnionRequest,
  rejectUnionRequest,
  listUnions,
  approveUnion,
  rejectUnion,
};
