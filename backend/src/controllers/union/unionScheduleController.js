const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const toTitleCase = require('../../utils/titleCase');
const { sendPushToMultipleUsers } = require('../../utils/pushNotification');
const olaMaps = require('../../services/olaMapsService');

const DAILY_SCHEDULE_LIMIT = 3;

const createUnionSchedulesBulk = asyncHandler(async (req, res) => {
  const { from_location, to_location, departure_time, union_driver_ids,
          from_lat, from_lng, to_lat, to_lng } = req.body;

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

  const fromTrimmed = toTitleCase(from_location);
  const toTrimmed   = toTitleCase(to_location);

  const client = await pool.connect();
  let created = [];
  try {
    await client.query('BEGIN');

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

  // FCM: only on first creation of the day (fire-and-forget, never awaited)
  if (todayCount === 0) {
    _sendUnionRideFcm(unionId, unionName, fcmEnabled);
  }

  // Respond IMMEDIATELY after the DB commit. Ride creation must never wait on —
  // or fail because of — the external Ola Maps geocode/route lookup. A slow or
  // failing map API used to time out the whole request and make rides appear to
  // "not create"; geo is now enriched in the background below.
  ApiResponse.created(
    { schedules: created, count: created.length },
    'Rides created for selected drivers'
  ).send(res);

  // Background best-effort: resolve coords + persist route metrics. Not awaited,
  // never touches `res`, fully self-contained error handling.
  _enrichSchedulesWithGeo(created, { from_lat, from_lng, to_lat, to_lng, fromTrimmed, toTrimmed });
});

/**
 * Best-effort geo enrichment for freshly-created union schedules. Runs AFTER the
 * response is sent so the external Ola Maps calls never block or break ride
 * creation. Prefers coords the admin already picked (sent from the app); only
 * geocodes the text as a fallback. Persists silently — skipped if geo columns
 * don't exist yet (error code 42703).
 */
async function _enrichSchedulesWithGeo(created, input) {
  if (!Array.isArray(created) || created.length === 0) return;
  const { from_lat, from_lng, to_lat, to_lng, fromTrimmed, toTrimmed } = input;
  try {
    let fromCoord = null, toCoord = null;
    const validCoord = (la, ln) =>
      olaMaps.isValidLatLng(typeof la === 'number' ? la : parseFloat(la), typeof ln === 'number' ? ln : parseFloat(ln));
    if (validCoord(from_lat, from_lng)) fromCoord = { lat: parseFloat(from_lat), lng: parseFloat(from_lng) };
    if (validCoord(to_lat, to_lng)) toCoord = { lat: parseFloat(to_lat), lng: parseFloat(to_lng) };

    if (!fromCoord || !toCoord) {
      const [g1, g2] = await Promise.all([
        fromCoord ? null : olaMaps.geocode(fromTrimmed),
        toCoord ? null : olaMaps.geocode(toTrimmed),
      ]);
      if (!fromCoord && g1) fromCoord = { lat: g1.lat, lng: g1.lng };
      if (!toCoord && g2) toCoord = { lat: g2.lat, lng: g2.lng };
    }
    if (!fromCoord || !toCoord) return;

    const routeInfo = await olaMaps.getRouteDistance(fromCoord, toCoord);
    const ids = created.map((r) => r.id);

    try {
      await pool.query(
        `UPDATE union_schedules
            SET from_lat = $1, from_lng = $2, to_lat = $3, to_lng = $4,
                route_distance_km = $5, route_duration_min = $6
          WHERE id = ANY($7::uuid[])`,
        [
          fromCoord.lat, fromCoord.lng, toCoord.lat, toCoord.lng,
          routeInfo?.distanceKm ?? null, routeInfo?.durationMin ?? null, ids,
        ]
      );
    } catch (e) {
      if (e.code !== '42703') logger.warn('Union schedule: geo persist failed:', e.message);
    }

    // Route polyline + bbox (separate best-effort UPDATE, pre-064 safe).
    if (routeInfo?.points && routeInfo.bbox) {
      try {
        const bb = routeInfo.bbox;
        await pool.query(
          `UPDATE union_schedules
             SET route_polyline = $1::jsonb,
                 route_min_lat = $2, route_max_lat = $3,
                 route_min_lng = $4, route_max_lng = $5
           WHERE id = ANY($6::uuid[])`,
          [JSON.stringify(routeInfo.points), bb.minLat, bb.maxLat, bb.minLng, bb.maxLng, ids]
        );
      } catch (e) {
        if (e.code !== '42703') logger.warn('Union schedule: polyline persist failed:', e.message);
      }
    }
  } catch (e) {
    logger.warn('Union schedule: geo enrich failed:', e.message);
  }
}

async function _sendUnionRideFcm(unionId, unionName, unionFcmEnabled) {
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

    const msgs = [
      { title: `🚖 ${unionName} — नई राइडें आ गईं!`, body: `इतवार को भी सफ़र रुकता नहीं! सीट पक्की करो, देर मत करो 😄` },
      { title: `🚖 ${unionName} — हफ्ते की पहली सवारी!`, body: `नया हफ्ता, नई राइड! अभी बुक करो, सीटें उड़ जाएँगी 💪` },
      { title: `🚖 ${unionName} — अपणी सवारी तैयार भई!`, body: `पहाड़ों का सफ़र, अपणी गाड़ी! जल्दी बुक करो 🏔️` },
      { title: `🚖 ${unionName} — राइडें लाइव!`, body: `आधा हफ्ता निकल गया, सफ़र अभी बाकी है! बुक करो 🎯` },
      { title: `🚖 ${unionName} — गाड़ियाँ तैयार!`, body: `भाई सीट पक्की कर लो, बाद में मत बोलना बताया नहीं! 😎` },
      { title: `🚖 ${unionName} — वीकेंड की सवारी!`, body: `छुट्टी का मूड बनाओ, सफ़र पक्का करो! अभी देखो 🚀` },
      { title: `🚖 ${unionName} — छुट्टी स्पेशल राइडें!`, body: `शनिवार है, निकल पड़ो! सीटें कम हैं, जल्दी करो 💺` },
    ];
    const dayIndex = new Date().getDay();
    const { title, body } = msgs[dayIndex];

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
