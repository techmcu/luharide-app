const { queryRead } = require('../config/database');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');

function clampInt(v, def, min, max) {
  const n = parseInt(v, 10);
  if (Number.isNaN(n)) return def;
  return Math.min(max, Math.max(min, n));
}

/**
 * Independent drivers & KYC-relevant users only (no plain passengers, no union_admin).
 * GET /api/admin/directory/independent-drivers?limit=&offset=
 */
const listIndependentDriversDirectory = asyncHandler(async (req, res) => {
  const limit = clampInt(req.query.limit, 100, 1, 500);
  const offset = clampInt(req.query.offset, 0, 0, 1_000_000);

  const where = `
    u.role <> 'union_admin'
    AND (
      u.role = 'driver'
      OR (u.driver_verification_status IS NOT NULL AND u.driver_verification_status <> 'none')
      OR EXISTS (
        SELECT 1 FROM driver_verification_requests dvr
        WHERE dvr.user_id = u.id AND dvr.status = 'pending'
      )
    )
  `;

  const countResult = await queryRead(
    `SELECT COUNT(*)::int AS n FROM users u WHERE ${where}`,
    []
  );
  const total = countResult.rows[0]?.n ?? 0;

  const result = await queryRead(
    `SELECT
       u.id,
       u.name,
       u.phone,
       u.email,
       u.role,
       u.driver_verification_status,
       u.driver_kyc_reupload_allowed,
       u.created_at
     FROM users u
     WHERE ${where}
     ORDER BY u.name ASC NULLS LAST, u.created_at DESC
     LIMIT $1 OFFSET $2`,
    [limit, offset]
  );

  ApiResponse.success(
    { drivers: result.rows, total, limit, offset },
    'Independent drivers directory'
  ).send(res);
});

/**
 * All unions in the database (admin directory).
 * GET /api/admin/directory/unions?limit=&offset=
 */
const listUnionsDirectory = asyncHandler(async (req, res) => {
  const limit = clampInt(req.query.limit, 100, 1, 500);
  const offset = clampInt(req.query.offset, 0, 0, 1_000_000);

  const countResult = await queryRead(`SELECT COUNT(*)::int AS n FROM unions`, []);
  const total = countResult.rows[0]?.n ?? 0;

  const result = await queryRead(
    `SELECT
       id,
       name,
       status,
       documents_status,
       contact_phone,
       contact_email,
       registration_number,
       created_at,
       updated_at
     FROM unions
     ORDER BY name ASC NULLS LAST, created_at DESC
     LIMIT $1 OFFSET $2`,
    [limit, offset]
  );

  ApiResponse.success(
    { unions: result.rows, total, limit, offset },
    'Unions directory'
  ).send(res);
});

module.exports = {
  listIndependentDriversDirectory,
  listUnionsDirectory,
};
