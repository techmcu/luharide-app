const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');

const getUnionRoutes = asyncHandler(async (req, res) => {
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
  const routesRes = await pool.query(
    `SELECT id, from_location, to_location, is_active, created_at
     FROM union_routes
     WHERE union_id = $1 AND is_active = TRUE
     ORDER BY from_location, to_location`,
    [unionId]
  );

  ApiResponse.success(
    { routes: routesRes.rows, count: routesRes.rows.length },
    'Union routes retrieved'
  ).send(res);
});

const addUnionRoute = asyncHandler(async (req, res) => {
  const { from_location, to_location } = req.body;

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
  const insertRes = await pool.query(
    `INSERT INTO union_routes (union_id, from_location, to_location, is_active)
     VALUES ($1, $2, $3, TRUE)
     RETURNING *`,
    [unionId, from_location.trim(), to_location.trim()]
  );

  const route = insertRes.rows[0];
  logger.info(`Union route added ${route.id} for union ${unionId} by admin ${req.user.id}`);

  ApiResponse.created(
    { route },
    'Route added for union'
  ).send(res);
});

const deleteUnionRoute = asyncHandler(async (req, res) => {
  const { routeId } = req.params;

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

  const result = await pool.query(
    'DELETE FROM union_routes WHERE id = $1 AND union_id = $2 RETURNING id',
    [routeId, unionId]
  );

  if (result.rowCount === 0) {
    throw ApiError.notFound('Route not found in your union');
  }

  logger.info(`Union route removed: ${routeId} from union ${unionId} by admin ${req.user.id}`);

  ApiResponse.success(null, 'Route removed').send(res);
});

module.exports = {
  getUnionRoutes,
  addUnionRoute,
  deleteUnionRoute,
};
