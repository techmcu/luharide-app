const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const toTitleCase = require('../../utils/titleCase');
const { sendPushToMultipleUsers } = require('../../utils/pushNotification');

const DAILY_SCHEDULE_LIMIT = 3;

const createUnionSchedulesBulk = asyncHandler(async (req, res) => {
  const { from_location, to_location, departure_time, union_driver_ids } = req.body;

  if (!Array.isArray(union_driver_ids) || union_driver_ids.length === 0) {
    throw ApiError.badRequest('At least one driver must be selected');
  }
  if (union_driver_ids.length > 50) {
    throw ApiError.badRequest('Maximum 50 drivers per batch');
  }

  const resUnion = await pool.query(
    `SELECT ua.union_id, u.name AS union_name, u.fcm_enabled
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
  const unionName = resUnion.rows[0].union_name;
  const fcmEnabled = resUnion.rows[0].fcm_enabled;

  // Daily limit check
  const countRes = await pool.query(
    `SELECT COUNT(*)::int AS cnt FROM union_daily_actions
     WHERE union_id = $1 AND action_type = 'bulk_schedule'
       AND created_at >= CURRENT_DATE`,
    [unionId]
  );
  const todayCount = countRes.rows[0].cnt;
  if (todayCount >= DAILY_SCHEDULE_LIMIT) {
    throw ApiError.badRequest(
      `आज की लिमिट पूरी हो गई। एक दिन में ${DAILY_SCHEDULE_LIMIT} बार ही राइड बना सकते हैं।`
    );
  }

  const driversCheck = await pool.query(
    `SELECT id FROM union_drivers
     WHERE union_id = $1 AND id = ANY($2::uuid[])`,
    [unionId, union_driver_ids]
  );
  if (driversCheck.rows.length !== union_driver_ids.length) {
    throw ApiError.badRequest('One or more drivers are invalid for this union');
  }

  const client = await pool.connect();
  let created = [];
  try {
    await client.query('BEGIN');

    const fromTrimmed = toTitleCase(from_location);
    const toTrimmed   = toTitleCase(to_location);

    const flatParams = [];
    const placeholders = union_driver_ids.map((driverId, i) => {
      const base = i * 5;
      flatParams.push(unionId, driverId, fromTrimmed, toTrimmed, departure_time);
      return `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5}, 'scheduled')`;
    });

    const insertRes = await client.query(
      `INSERT INTO union_schedules (union_id, union_driver_id, from_location, to_location, departure_time, status)
       VALUES ${placeholders.join(', ')}
       RETURNING *`,
      flatParams
    );
    created = insertRes.rows;

    // Track daily action
    await client.query(
      `INSERT INTO union_daily_actions (union_id, action_type) VALUES ($1, 'bulk_schedule')`,
      [unionId]
    );

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  logger.info(
    `Union schedules created for union ${unionId} by admin ${req.user.id} count=${created.length}`
  );

  // FCM: only on first creation of the day
  if (todayCount === 0) {
    _sendUnionRideFcm(unionId, unionName, fcmEnabled, toTitleCase(from_location), toTitleCase(to_location));
  }

  ApiResponse.created(
    { schedules: created, count: created.length },
    'Rides created for selected drivers'
  ).send(res);
});

async function _sendUnionRideFcm(unionId, unionName, unionFcmEnabled, from, to) {
  try {
    if (!unionFcmEnabled) return;

    const globalRes = await pool.query(
      `SELECT value FROM settings WHERE key = 'fcm_global_union_rides'`
    );
    const globalEnabled = (globalRes.rows[0]?.value ?? 'true') === 'true';
    if (!globalEnabled) return;

    const passRes = await pool.query(
      `SELECT id FROM users WHERE role = 'passenger' AND is_active = true`
    );
    const passengerIds = passRes.rows.map(r => r.id);
    if (passengerIds.length === 0) return;

    const title = `${from} → ${to} नई राइड!`;
    const body = `${unionName} ने ${from} → ${to} की राइड अपलोड की! जल्दी करें, सीट सीमित हैं।`;

    await sendPushToMultipleUsers(passengerIds, title, body, {
      type: 'union_ride_created',
      union_id: unionId,
    });
    logger.info({ msg: 'FCM union ride broadcast sent', unionId, passengers: passengerIds.length });
  } catch (err) {
    logger.warn({ msg: 'FCM union ride broadcast failed', unionId, error: err.message });
  }
}

const getUnionSchedules = asyncHandler(async (req, res) => {
  const scope = (req.query.scope || 'current').toString();

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

  if (scope === 'recent') {
    return ApiResponse.success({ schedules: [], count: 0 }, 'Union schedules retrieved').send(res);
  }

  const result = await pool.query(
    `
    SELECT
      CASE
        WHEN s.status = 'scheduled' AND s.departure_time <= NOW()
          THEN 'completed'
        ELSE s.status
      END AS status,
      s.id,
      s.union_id,
      s.union_driver_id,
      s.from_location,
      s.to_location,
      s.departure_time,
      s.created_at,
      d.name AS driver_name,
      d.vehicle_number,
      d.phone AS driver_phone,
      d.whatsapp_number,
      (
        s.status = 'scheduled'
        AND s.departure_time > NOW()
        AND s.created_at >= NOW() - INTERVAL '1 hour'
      ) AS can_cancel
    FROM union_schedules s
    JOIN union_drivers d ON d.id = s.union_driver_id
    WHERE s.union_id = $1
      AND s.departure_time >= CURRENT_DATE::timestamp
      AND s.departure_time < (CURRENT_DATE::timestamp + INTERVAL '10 days')
      AND s.status IN ('scheduled','completed')
    ORDER BY s.departure_time ASC
    `,
    [unionId]
  );

  ApiResponse.success(
    { schedules: result.rows, count: result.rows.length },
    'Union schedules retrieved'
  ).send(res);
});

const cancelUnionSchedule = asyncHandler(async (req, res) => {
  const { id } = req.params;

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

  const schedRes = await pool.query(
    `SELECT
       status,
       departure_time,
       created_at,
       (
         status = 'scheduled'
         AND departure_time > NOW()
         AND created_at >= NOW() - INTERVAL '1 hour'
       ) AS can_cancel
     FROM union_schedules
     WHERE id = $1 AND union_id = $2`,
    [id, unionId]
  );
  if (schedRes.rows.length === 0) {
    return ApiResponse.success({ id, status: 'cancelled' }, 'Ride already removed').send(res);
  }

  const canCancel = !!schedRes.rows[0].can_cancel;

  if (!canCancel) {
    throw ApiError.badRequest('This ride can be cancelled only within 1 hour of creation and before departure time');
  }

  const delRes = await pool.query(
    `DELETE FROM union_schedules
     WHERE id = $1
       AND union_id = $2
       AND status = 'scheduled'
       AND departure_time > NOW()
       AND created_at >= NOW() - INTERVAL '1 hour'
     RETURNING id`,
    [id, unionId]
  );

  if (delRes.rowCount === 0) {
    throw ApiError.badRequest('This ride can no longer be cancelled');
  }

  logger.info(`Union schedule cancelled ${id} for union ${unionId} by admin ${req.user.id}`);

  ApiResponse.success(
    { id, status: 'cancelled' },
    'Ride cancelled successfully'
  ).send(res);
});

module.exports = {
  createUnionSchedulesBulk,
  getUnionSchedules,
  cancelUnionSchedule,
};
