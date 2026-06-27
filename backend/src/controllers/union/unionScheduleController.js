const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const toTitleCase = require('../../utils/titleCase');
const { sendPushToMultipleUsers } = require('../../utils/pushNotification');
const olaMaps = require('../../services/olaMapsService');
const { IST_TODAY_START } = require('../../utils/istDay');

const DAILY_SCHEDULE_LIMIT = 3;            // publishes (button clicks) per union per day
const MAX_SCHEDULES_PER_PUBLISH = 50;      // rides (drivers) per single publish
const PAST_GRACE_MS = 60 * 1000;           // tolerate 1 min clock skew / submit latency

/**
 * Normalize an incoming departure time to a true UTC instant (ISO-8601 string).
 *
 * THE TIME BUG: `union_schedules.departure_time` is TIMESTAMPTZ. The app's date/time
 * picker yields a NAKED local datetime (`"2026-06-27T10:00:00.000"` — no zone). If that
 * is handed to Postgres as-is, a UTC DB session reads it as 10:00 UTC = 15:30 IST, so the
 * passenger search showed 15:30 for a ride the union set for 10:00. We fix it at the door:
 * a naked value is IST wall-clock → attach +05:30; an explicit-zone value (Z or ±hh:mm,
 * sent by newer builds) is already an instant → respect it. Returns null if unparseable.
 *
 * Doing this server-side means EVERY installed app build is corrected immediately — no APK
 * update required. Pure (no I/O) → unit-testable.
 */
function departureToInstantISO(value) {
  if (value === null || value === undefined) return null;
  const s = String(value).trim();
  if (!s) return null;
  const hasZone = /[zZ]$/.test(s) || /[+-]\d{2}:?\d{2}$/.test(s);
  const d = new Date(hasZone ? s : `${s}+05:30`);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}

/**
 * Normalize the request body into a flat list of schedule items. ONE publish can
 * carry up to 50 rides, each with its OWN route + time (drivers going different
 * places in one click). Supports two body shapes:
 *  - NEW batch: { schedules: [{ union_driver_id, from_location, to_location,
 *      from_lat?, from_lng?, to_lat?, to_lng?, departure_time }, ...] }
 *  - LEGACY (old APKs): { union_driver_ids: [...], from_location, to_location,
 *      departure_time, from_lat?, ... } — one shared route+time for all drivers.
 * Pure (no I/O) → unit-testable. Caller validates the result.
 */
function normalizeScheduleItems(body = {}) {
  const num = (v) => {
    if (v === null || v === undefined || v === '') return null;
    const n = typeof v === 'number' ? v : parseFloat(v);
    return Number.isFinite(n) ? n : null;
  };
  const str = (v) => (v === null || v === undefined ? '' : String(v).trim());

  if (Array.isArray(body.schedules)) {
    return body.schedules.map((s = {}) => ({
      unionDriverId: str(s.union_driver_id),
      fromLocation: str(s.from_location),
      toLocation: str(s.to_location),
      fromLat: num(s.from_lat), fromLng: num(s.from_lng),
      toLat: num(s.to_lat), toLng: num(s.to_lng),
      departureTime: departureToInstantISO(s.departure_time),
    }));
  }

  const ids = Array.isArray(body.union_driver_ids) ? body.union_driver_ids : [];
  return ids.map((id) => ({
    unionDriverId: str(id),
    fromLocation: str(body.from_location),
    toLocation: str(body.to_location),
    fromLat: num(body.from_lat), fromLng: num(body.from_lng),
    toLat: num(body.to_lat), toLng: num(body.to_lng),
    departureTime: departureToInstantISO(body.departure_time),
  }));
}

/** A departure time is valid only if it parses AND is not in the past (1-min grace). */
function isFutureDeparture(value, now = Date.now()) {
  if (!value) return false;
  const t = new Date(value).getTime();
  if (Number.isNaN(t)) return false;
  return t >= now - PAST_GRACE_MS;
}

/**
 * Validate normalized items. Throws ApiError(400) with a specific message on the
 * first problem. Returns the DISTINCT driver ids for the ownership check. Pure.
 */
function validateScheduleItems(items, now = Date.now()) {
  if (!Array.isArray(items) || items.length === 0) {
    throw ApiError.badRequest('At least one ride must be added');
  }
  if (items.length > MAX_SCHEDULES_PER_PUBLISH) {
    throw ApiError.badRequest(`Maximum ${MAX_SCHEDULES_PER_PUBLISH} rides per publish`);
  }
  for (const it of items) {
    if (!it.unionDriverId) throw ApiError.badRequest('Each ride must have a driver');
    if (!it.fromLocation || !it.toLocation) {
      throw ApiError.badRequest('Each ride must have a from and to location');
    }
    if (!isFutureDeparture(it.departureTime, now)) {
      throw ApiError.badRequest('Rides can only be scheduled for a future date and time');
    }
  }
  return [...new Set(items.map((it) => it.unionDriverId))];
}

const createUnionSchedulesBulk = asyncHandler(async (req, res) => {
  // 1. Parse + validate the whole batch BEFORE any DB write (clear 400s, no partial work).
  const items = normalizeScheduleItems(req.body);
  const distinctDriverIds = validateScheduleItems(items);

  // 2. Resolve admin → approved union.
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

  // 3. Every driver in the batch must belong to THIS union.
  const driversCheck = await pool.query(
    `SELECT id FROM union_drivers WHERE union_id = $1 AND id = ANY($2::uuid[])`,
    [unionId, distinctDriverIds]
  );
  if (driversCheck.rows.length !== distinctDriverIds.length) {
    throw ApiError.badRequest('One or more drivers are invalid for this union');
  }

  // 4. Title-case location text once per item.
  for (const it of items) {
    it.fromLocation = toTitleCase(it.fromLocation);
    it.toLocation = toTitleCase(it.toLocation);
  }

  // 5. Atomic publish: lock the union row so two simultaneous clicks can't BOTH
  //    pass the daily-limit check (race-safe). Count, insert all rides, and record
  //    EXACTLY ONE daily-action — all in one transaction. All-or-nothing.
  const client = await pool.connect();
  let created = [];
  let todayCount = 0;
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM unions WHERE id = $1 FOR UPDATE', [unionId]);

    const countRes = await client.query(
      `SELECT COUNT(*)::int AS cnt FROM union_daily_actions
       WHERE union_id = $1 AND action_type = 'bulk_schedule'
         AND created_at >= ${IST_TODAY_START}`,
      [unionId]
    );
    todayCount = countRes.rows[0].cnt;
    if (todayCount >= DAILY_SCHEDULE_LIMIT) {
      throw ApiError.badRequest(
        `आज की लिमिट पूरी हो गई। एक दिन में ${DAILY_SCHEDULE_LIMIT} बार ही राइड बना सकते हैं।`
      );
    }

    const flatParams = [];
    const placeholders = items.map((it, i) => {
      const b = i * 5;
      flatParams.push(unionId, it.unionDriverId, it.fromLocation, it.toLocation, it.departureTime);
      return `($${b + 1}, $${b + 2}, $${b + 3}, $${b + 4}, $${b + 5}, 'scheduled')`;
    });
    const insertRes = await client.query(
      `INSERT INTO union_schedules (union_id, union_driver_id, from_location, to_location, departure_time, status)
       VALUES ${placeholders.join(', ')}
       RETURNING *`,
      flatParams
    );
    created = insertRes.rows;

    // ONE daily-action for the whole publish — driver/route count never matters.
    await client.query(
      `INSERT INTO union_daily_actions (union_id, action_type) VALUES ($1, 'bulk_schedule')`,
      [unionId]
    );

    await client.query('COMMIT');
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) { /* connection already broken */ }
    throw err;
  } finally {
    client.release();
  }

  logger.info(
    `Union schedules created for union ${unionId} by admin ${req.user.id} count=${created.length}`
  );

  // FCM: only on the first publish of the day (fire-and-forget, never awaited).
  if (todayCount === 0) {
    _sendUnionRideFcm(unionId, unionName, fcmEnabled);
  }

  // Respond IMMEDIATELY after the DB commit — ride creation must never wait on or
  // fail because of the external Ola Maps lookup (geo is enriched in background).
  ApiResponse.created(
    { schedules: created, count: created.length },
    'Rides created for selected drivers'
  ).send(res);

  _enrichSchedulesWithGeo(created, items);
});

/**
 * Best-effort geo enrichment for freshly-created union schedules. Runs AFTER the
 * response is sent so the external Ola Maps calls never block or break ride
 * creation. Prefers coords the admin already picked (sent from the app); only
 * geocodes the text as a fallback. Persists silently — skipped if geo columns
 * don't exist yet (error code 42703).
 */
async function _enrichSchedulesWithGeo(created, items) {
  if (!Array.isArray(created) || created.length === 0) return;
  try {
    // Zip each created row with its source item (a single INSERT returns rows in
    // VALUES order), then group ids by distinct route so each route's geo is
    // resolved only ONCE even across many drivers.
    const groups = new Map(); // key -> { item, ids: [] }
    created.forEach((row, i) => {
      const it = items[i];
      if (!it || !row || !row.id) return;
      const key = `${it.fromLat},${it.fromLng},${it.toLat},${it.toLng}|${it.fromLocation}|${it.toLocation}`;
      const g = groups.get(key) || { item: it, ids: [] };
      g.ids.push(row.id);
      groups.set(key, g);
    });

    for (const { item, ids } of groups.values()) {
      await _persistRouteGeo(item, ids); // sequential — keeps Ola Maps load gentle
    }
  } catch (e) {
    logger.warn('Union schedule: geo enrich failed:', e.message);
  }
}

/** Resolve + persist geo for ONE route shared by `ids`. Best-effort, never throws. */
async function _persistRouteGeo(item, ids) {
  try {
    let fromCoord = null, toCoord = null;
    if (olaMaps.isValidLatLng(item.fromLat, item.fromLng)) fromCoord = { lat: item.fromLat, lng: item.fromLng };
    if (olaMaps.isValidLatLng(item.toLat, item.toLng)) toCoord = { lat: item.toLat, lng: item.toLng };

    if (!fromCoord || !toCoord) {
      const [g1, g2] = await Promise.all([
        fromCoord ? null : olaMaps.geocode(item.fromLocation),
        toCoord ? null : olaMaps.geocode(item.toLocation),
      ]);
      if (!fromCoord && g1) fromCoord = { lat: g1.lat, lng: g1.lng };
      if (!toCoord && g2) toCoord = { lat: g2.lat, lng: g2.lng };
    }
    if (!fromCoord || !toCoord) return;

    const routeInfo = await olaMaps.getRouteDistance(fromCoord, toCoord);

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
    logger.warn('Union schedule: route geo failed:', e.message);
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
        WHEN s.status = 'scheduled'
             AND s.departure_time + make_interval(mins => COALESCE(s.route_duration_min, 120)::int) <= NOW()
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
      AND s.departure_time >= NOW() - INTERVAL '30 days'
      AND s.status IN ('scheduled','completed')
    ORDER BY s.departure_time DESC
    LIMIT 200
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
  // Exported additively for unit testing — pure helpers, no behavior change.
  normalizeScheduleItems,
  departureToInstantISO,
  isFutureDeparture,
  validateScheduleItems,
  DAILY_SCHEDULE_LIMIT,
  MAX_SCHEDULES_PER_PUBLISH,
};
