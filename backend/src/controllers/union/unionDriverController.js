const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');

const getUnionDrivers = asyncHandler(async (req, res) => {
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

const addUnionDriver = asyncHandler(async (req, res) => {
  const { name, vehicle_number, phone, whatsapp_number } = req.body;

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
    `INSERT INTO union_drivers (union_id, name, vehicle_number, phone, whatsapp_number)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING *`,
    [unionId, name.trim(), vehicle_number.trim(), phone || null, whatsapp_number || null]
  );

  const driver = insertRes.rows[0];
  logger.info(`Union driver added ${driver.id} for union ${unionId} by admin ${req.user.id}`);

  ApiResponse.created(
    { driver },
    'Driver added to union'
  ).send(res);
});

const deleteUnionDriver = asyncHandler(async (req, res) => {
  const { driverId } = req.params;

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

  const driverCheck = await pool.query(
    'SELECT id, name FROM union_drivers WHERE id = $1 AND union_id = $2',
    [driverId, unionId]
  );
  if (driverCheck.rows.length === 0) {
    throw ApiError.notFound('Driver not found in your union');
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    await client.query(
      `UPDATE union_schedules SET status = 'cancelled'
       WHERE union_driver_id = $1 AND status = 'scheduled' AND departure_time > NOW()`,
      [driverId]
    );

    await client.query(
      'DELETE FROM union_drivers WHERE id = $1 AND union_id = $2',
      [driverId, unionId]
    );

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  const driverName = driverCheck.rows[0].name;
  logger.info(`Union driver removed: ${driverId} (${driverName}) from union ${unionId} by admin ${req.user.id}`);

  ApiResponse.success(null, 'Driver removed from union').send(res);
});

module.exports = {
  getUnionDrivers,
  addUnionDriver,
  deleteUnionDriver,
};
