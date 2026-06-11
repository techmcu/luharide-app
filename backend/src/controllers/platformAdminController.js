const { pool, queryRead } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { emitNotificationToUser } = require('../socket/realtimeEmitter');

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
// GET /api/platform-admin/dashboard
// ---------------------------------------------------------------------------
const getDashboard = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const days = Math.min(365, Math.max(1, parseInt(req.query.days, 10) || 180));

  const { rows } = await queryRead(`
    SELECT
      -- Users (all-time)
      (SELECT COUNT(*)::int FROM users WHERE role = 'passenger')   AS passengers,
      (SELECT COUNT(*)::int FROM users WHERE role = 'driver')      AS drivers,
      (SELECT COUNT(*)::int FROM users WHERE role = 'union_admin') AS union_admins,
      (SELECT COUNT(*)::int FROM users)                            AS total_users,
      -- Trips (within period)
      (SELECT COUNT(*)::int FROM trips WHERE created_at >= NOW() - make_interval(days => $1))  AS total_trips,
      (SELECT COUNT(*)::int FROM trips WHERE status = 'scheduled'   AND created_at >= NOW() - make_interval(days => $1)) AS scheduled_trips,
      (SELECT COUNT(*)::int FROM trips WHERE status = 'in_progress')                            AS active_trips,
      (SELECT COUNT(*)::int FROM trips WHERE status = 'completed'   AND created_at >= NOW() - make_interval(days => $1)) AS completed_trips,
      (SELECT COUNT(*)::int FROM trips WHERE status = 'cancelled'   AND created_at >= NOW() - make_interval(days => $1)) AS cancelled_trips,
      -- Upcoming: future scheduled rides
      (SELECT COUNT(*)::int FROM trips WHERE status = 'scheduled' AND departure_time > NOW())   AS upcoming_trips,
      -- Bookings (within period)
      (SELECT COUNT(*)::int FROM bookings WHERE status = 'confirmed' AND created_at >= NOW() - make_interval(days => $1)) AS confirmed_bookings,
      (SELECT COUNT(*)::int FROM bookings WHERE status = 'pending'   AND created_at >= NOW() - make_interval(days => $1)) AS pending_bookings,
      (SELECT COUNT(*)::int FROM bookings WHERE status = 'cancelled' AND created_at >= NOW() - make_interval(days => $1)) AS cancelled_bookings,
      -- Always-current stats
      (SELECT COUNT(*)::int FROM trips WHERE departure_time::date = CURRENT_DATE) AS today_trips,
      (SELECT COUNT(*)::int FROM users WHERE created_at >= NOW() - INTERVAL '7 days') AS new_users_week,
      (SELECT COUNT(DISTINCT driver_id)::int FROM trips WHERE created_at >= NOW() - INTERVAL '30 days') AS active_drivers,
      (SELECT COUNT(*)::int FROM driver_verification_requests WHERE status = 'pending') AS pending_driver_kyc,
      (SELECT COUNT(*)::int FROM unions WHERE status = 'pending') AS pending_union_requests,
      (SELECT COUNT(*)::int FROM unions WHERE status = 'approved') AS total_unions
  `, [days]);

  const data = rows[0];
  data.days_filter = days;

  ApiResponse.success(data, 'Dashboard stats').send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/users?search=&role=&page=1&limit=20
// ---------------------------------------------------------------------------
const getUsers = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const search = (req.query.search || '').trim();
  const role = (req.query.role || '').trim().toLowerCase();
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 20));
  const offset = (page - 1) * limit;

  const conditions = [];
  const params = [];
  let idx = 1;

  if (search) {
    const pattern = `%${search}%`;
    conditions.push(`(u.name ILIKE $${idx} OR u.phone ILIKE $${idx} OR u.email ILIKE $${idx})`);
    params.push(pattern);
    idx++;
  }
  if (role && ['passenger', 'driver', 'union_admin'].includes(role)) {
    conditions.push(`u.role = $${idx}`);
    params.push(role);
    idx++;
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  const countRes = await queryRead(
    `SELECT COUNT(*)::int AS total FROM users u ${where}`,
    params
  );

  const usersRes = await queryRead(
    `SELECT u.id, u.name, u.phone, u.email, u.role, u.is_active, u.is_verified,
            u.driver_verification_status, u.created_at, u.last_login
     FROM users u ${where}
     ORDER BY u.created_at DESC
     LIMIT $${idx} OFFSET $${idx + 1}`,
    [...params, limit, offset]
  );

  ApiResponse.success({
    users: usersRes.rows,
    total: countRes.rows[0].total,
    page,
    limit,
    totalPages: Math.ceil(countRes.rows[0].total / limit),
  }, 'Users list').send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/users/:id
// ---------------------------------------------------------------------------
const getUserDetail = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;

  const userRes = await queryRead(
    `SELECT id, name, phone, email, role, is_active, is_verified,
            driver_verification_status, profile_image_url,
            bio, whatsapp_number, created_at, last_login
     FROM users WHERE id = $1`,
    [id]
  );
  if (userRes.rows.length === 0) throw ApiError.notFound('User not found');

  const tripsRes = await queryRead(
    `SELECT id, from_location, to_location, departure_time, status,
            fare_per_seat, available_seats, total_capacity, vehicle_number
     FROM trips WHERE driver_id = $1
     ORDER BY departure_time DESC LIMIT 20`,
    [id]
  );

  const bookingsRes = await queryRead(
    `SELECT b.id, b.trip_id, b.seat_numbers, b.status, b.total_amount, b.created_at,
            t.from_location, t.to_location, t.departure_time
     FROM bookings b
     JOIN trips t ON b.trip_id = t.id
     WHERE b.passenger_id = $1
     ORDER BY b.created_at DESC LIMIT 20`,
    [id]
  );

  const ratingsRes = await queryRead(
    `SELECT
       COUNT(*)::int AS total_ratings,
       ROUND(AVG(rating)::numeric, 1) AS avg_rating,
       COUNT(CASE WHEN rating >= 4 THEN 1 END)::int AS good_ratings
     FROM ride_ratings WHERE rated_user_id = $1`,
    [id]
  );

  ApiResponse.success({
    user: userRes.rows[0],
    trips: tripsRes.rows,
    bookings: bookingsRes.rows,
    ratings: ratingsRes.rows[0],
  }, 'User detail').send(res);
});

// ---------------------------------------------------------------------------
// PATCH /api/platform-admin/users/:id/active  { is_active: bool }
// ---------------------------------------------------------------------------
const toggleUserActive = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;
  const { is_active } = req.body;

  if (typeof is_active !== 'boolean') {
    throw ApiError.badRequest('is_active must be a boolean');
  }

  if (id === req.user.id) {
    throw ApiError.badRequest('Cannot suspend your own account');
  }

  if (!is_active && adminEmail) {
    const target = await pool.query('SELECT email FROM users WHERE id = $1', [id]);
    const targetEmail = target.rows[0]?.email
      ? String(target.rows[0].email).toLowerCase().trim()
      : null;
    if (targetEmail === adminEmail) {
      throw ApiError.badRequest('Cannot suspend the platform admin account');
    }
  }

  const result = await pool.query(
    `UPDATE users SET is_active = $1, updated_at = NOW() WHERE id = $2
     RETURNING id, name, email, is_active`,
    [is_active, id]
  );

  if (result.rows.length === 0) throw ApiError.notFound('User not found');

  const action = is_active ? 'activated' : 'suspended';
  logger.info(`Platform admin ${req.user.id} ${action} user ${id}`);

  ApiResponse.success(result.rows[0], `User ${action} successfully`).send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/trips?status=&date=&search=&page=1&limit=20
// ---------------------------------------------------------------------------
const getTrips = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const status = (req.query.status || '').trim().toLowerCase();
  const date = (req.query.date || '').trim();
  const search = (req.query.search || '').trim();
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 20));
  const offset = (page - 1) * limit;

  const conditions = [];
  const params = [];
  let idx = 1;

  if (status && ['scheduled', 'boarding', 'in_progress', 'completed', 'cancelled'].includes(status)) {
    conditions.push(`t.status = $${idx}`);
    params.push(status);
    idx++;
  }
  if (date) {
    conditions.push(`t.departure_time::date = $${idx}::date`);
    params.push(date);
    idx++;
  }
  if (search) {
    const pattern = `%${search}%`;
    conditions.push(`(t.from_location ILIKE $${idx} OR t.to_location ILIKE $${idx} OR u.name ILIKE $${idx})`);
    params.push(pattern);
    idx++;
  }

  const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

  const countRes = await queryRead(
    `SELECT COUNT(*)::int AS total FROM trips t
     LEFT JOIN users u ON t.driver_id = u.id ${where}`,
    params
  );

  const tripsRes = await queryRead(
    `SELECT t.id, t.from_location, t.to_location, t.departure_time, t.status,
            t.fare_per_seat, t.available_seats, t.total_capacity, t.vehicle_number,
            t.created_at,
            u.name AS driver_name, u.phone AS driver_phone, u.email AS driver_email
     FROM trips t
     LEFT JOIN users u ON t.driver_id = u.id
     ${where}
     ORDER BY t.departure_time DESC
     LIMIT $${idx} OFFSET $${idx + 1}`,
    [...params, limit, offset]
  );

  ApiResponse.success({
    trips: tripsRes.rows,
    total: countRes.rows[0].total,
    page,
    limit,
    totalPages: Math.ceil(countRes.rows[0].total / limit),
  }, 'Trips list').send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/trips/:id
// ---------------------------------------------------------------------------
const getTripDetail = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;

  const tripRes = await queryRead(
    `SELECT t.*,
            u.name AS driver_name, u.phone AS driver_phone, u.email AS driver_email,
            u.whatsapp_number AS driver_whatsapp
     FROM trips t
     LEFT JOIN users u ON t.driver_id = u.id
     WHERE t.id = $1`,
    [id]
  );
  if (tripRes.rows.length === 0) throw ApiError.notFound('Trip not found');

  const bookingsRes = await queryRead(
    `SELECT b.id, b.passenger_id, b.seat_numbers, b.status, b.total_amount,
            b.created_at, b.confirmed_at, b.cancelled_at, b.cancellation_reason,
            p.name AS passenger_name, p.phone AS passenger_phone, p.email AS passenger_email
     FROM bookings b
     LEFT JOIN users p ON b.passenger_id = p.id
     WHERE b.trip_id = $1
     ORDER BY b.created_at DESC`,
    [id]
  );

  ApiResponse.success({
    trip: tripRes.rows[0],
    bookings: bookingsRes.rows,
  }, 'Trip detail').send(res);
});

// ---------------------------------------------------------------------------
// POST /api/platform-admin/trips/:id/cancel   { reason }
// ---------------------------------------------------------------------------
const cancelTrip = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;
  const { reason } = req.body || {};
  if (reason && reason.length > 500) throw ApiError.badRequest('Reason must be under 500 characters');

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tripRes = await client.query(
      `SELECT id, status, driver_id FROM trips WHERE id = $1 FOR UPDATE`,
      [id]
    );
    if (tripRes.rows.length === 0) {
      await client.query('ROLLBACK');
      throw ApiError.notFound('Trip not found');
    }
    const trip = tripRes.rows[0];
    if (trip.status === 'cancelled' || trip.status === 'completed') {
      await client.query('ROLLBACK');
      throw ApiError.badRequest(`Trip is already ${trip.status}`);
    }

    const activeBookings = await client.query(
      `SELECT id, passenger_id, seat_numbers FROM bookings
       WHERE trip_id = $1 AND status IN ('pending', 'confirmed')
       FOR UPDATE`,
      [id]
    );

    const totalSeatCount = activeBookings.rows
      .reduce((sum, r) => sum + (Array.isArray(r.seat_numbers) ? r.seat_numbers.length : 0), 0);

    if (activeBookings.rows.length > 0) {
      await client.query(
        `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
                cancellation_reason = $2
         WHERE id = ANY($1::uuid[])`,
        [activeBookings.rows.map(r => r.id), reason || 'Cancelled by platform admin']
      );
    }

    await client.query(
      `UPDATE trips SET status = 'cancelled', updated_at = NOW(),
              available_seats = available_seats + $2
       WHERE id = $1`,
      [id, totalSeatCount]
    );

    const affectedBookings = { rows: activeBookings.rows, rowCount: activeBookings.rowCount };

    for (const row of affectedBookings.rows) {
      try {
        await client.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'trip_cancelled', 'Ride cancelled by admin',
                   $2, $3::jsonb)`,
          [
            row.passenger_id,
            reason || 'This ride has been cancelled by the platform admin. You are not charged.',
            JSON.stringify({ trip_id: id }),
          ]
        );
      } catch (notifErr) {
        logger.warn(`Failed to notify passenger ${row.passenger_id} about trip ${id} cancel:`, notifErr.message);
      }
    }

    if (trip.driver_id) {
      await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'trip_cancelled', 'Your ride was cancelled by admin',
                 $2, $3::jsonb)`,
        [
          trip.driver_id,
          reason || 'Your ride has been cancelled by the platform admin.',
          JSON.stringify({ trip_id: id }),
        ]
      );
    }

    await client.query('COMMIT');
    logger.info(`Platform admin ${req.user.id} cancelled trip ${id}`);

    if (affectedBookings.rows.length > 0) {
      try {
        await pool.query(
          'DELETE FROM pending_rate_notifications WHERE booking_id = ANY($1::uuid[])',
          [affectedBookings.rows.map(r => r.id)]
        );
      } catch (e) {
        if (e.code !== '42P01') logger.warn('Rate notification cleanup failed:', e.message);
      }
    }

    ApiResponse.success(
      { tripId: id, cancelledBookings: affectedBookings.rowCount },
      'Trip cancelled'
    ).send(res);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/revenue?period=week|month|all
// ---------------------------------------------------------------------------
const getRevenueOverview = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const period = (req.query.period || 'month').trim().toLowerCase();
  let interval;
  if (period === 'week') interval = '7 days';
  else if (period === 'all') interval = '10 years';
  else interval = '30 days';

  const summaryRes = await queryRead(`
    SELECT
      COALESCE(SUM(b.total_amount), 0)::numeric AS total_revenue,
      COUNT(*)::int AS total_bookings,
      COALESCE(ROUND(AVG(b.total_amount)::numeric, 2), 0) AS avg_booking_amount
    FROM bookings b
    WHERE b.status = 'confirmed'
      AND b.created_at >= NOW() - $1::interval
  `, [interval]);

  const topRoutesRes = await queryRead(`
    SELECT t.from_location, t.to_location,
           COUNT(b.id)::int AS booking_count,
           COALESCE(SUM(b.total_amount), 0)::numeric AS route_revenue
    FROM bookings b
    JOIN trips t ON b.trip_id = t.id
    WHERE b.status = 'confirmed'
      AND b.created_at >= NOW() - $1::interval
    GROUP BY t.from_location, t.to_location
    ORDER BY booking_count DESC
    LIMIT 10
  `, [interval]);

  const topDriversRes = await queryRead(`
    SELECT u.id, u.name, u.phone,
           COUNT(DISTINCT t.id)::int AS trip_count,
           COUNT(b.id)::int AS booking_count,
           COALESCE(SUM(b.total_amount), 0)::numeric AS driver_revenue,
           COALESCE(ROUND(AVG(rr.rating)::numeric, 1), 0) AS avg_rating
    FROM users u
    JOIN trips t ON u.id = t.driver_id
    LEFT JOIN bookings b ON t.id = b.trip_id AND b.status = 'confirmed'
                        AND b.created_at >= NOW() - $1::interval
    LEFT JOIN ride_ratings rr ON b.id = rr.booking_id AND rr.rated_user_id = u.id
    WHERE t.created_at >= NOW() - $1::interval
    GROUP BY u.id, u.name, u.phone
    ORDER BY trip_count DESC
    LIMIT 10
  `, [interval]);

  ApiResponse.success({
    period,
    summary: summaryRes.rows[0],
    topRoutes: topRoutesRes.rows,
    topDrivers: topDriversRes.rows,
  }, 'Revenue overview').send(res);
});

// ===========================================================================
// PHASE 2 — Bulk Notifications, Complaints, App Config
// ===========================================================================

// ---------------------------------------------------------------------------
// POST /api/platform-admin/notifications/bulk  { segment, title, body }
// ---------------------------------------------------------------------------
const sendBulkNotification = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { segment, title, body } = req.body || {};

  if (!title || !body) throw ApiError.badRequest('title and body are required');
  if (title.length > 50) throw ApiError.badRequest('Title max 50 characters (push notification me zyada nahi dikhta)');
  if (body.length > 150) throw ApiError.badRequest('Body max 150 characters (push notification me zyada nahi dikhta)');
  const validSegments = ['all', 'passenger', 'driver', 'drivers', 'union_admin', 'union_admins'];
  if (!segment || !validSegments.includes(segment)) {
    throw ApiError.badRequest(`segment must be one of: all, passenger, driver, union_admin`);
  }

  const dupCheck = await pool.query(
    `SELECT id FROM broadcasts
     WHERE title = $1 AND body = $2 AND created_at > NOW() - INTERVAL '1 hour'
     LIMIT 1`,
    [title, body]
  );
  if (dupCheck.rows.length > 0) {
    throw ApiError.badRequest('Yahi notification 1 ghante mein pehle bhi bheja ja chuka hai. Duplicate bhejne se users pareshaan hote hain.');
  }

  const roleFilter = segment === 'all' ? null
    : (segment === 'driver' || segment === 'drivers') ? 'driver'
    : (segment === 'union_admin' || segment === 'union_admins') ? 'union_admin'
    : 'passenger';

  const countSql = roleFilter
    ? `SELECT COUNT(*)::int AS total FROM users WHERE role = $1 AND is_active = true`
    : `SELECT COUNT(*)::int AS total FROM users WHERE is_active = true`;
  const countParams = roleFilter ? [roleFilter] : [];
  const countRes = await pool.query(countSql, countParams);
  const userCount = countRes.rows[0]?.total || 0;

  if (userCount === 0) throw ApiError.badRequest('No active users in this segment');
  if (userCount > 10000) throw ApiError.badRequest(`Segment has ${userCount} users — contact dev team for large broadcasts`);

  const insertSql = roleFilter
    ? `INSERT INTO notifications (user_id, type, title, body)
       SELECT id, 'admin_broadcast', $1, $2 FROM users WHERE role = $3 AND is_active = true
       RETURNING id, user_id`
    : `INSERT INTO notifications (user_id, type, title, body)
       SELECT id, 'admin_broadcast', $1, $2 FROM users WHERE is_active = true
       RETURNING id, user_id`;

  const params = roleFilter ? [title, body, roleFilter] : [title, body];
  const result = await pool.query(insertSql, params);

  for (const row of result.rows) {
    try { emitNotificationToUser(row.user_id, { ...row, type: 'admin_broadcast', title, body, is_read: false }); } catch (_) {}
  }

  await pool.query(
    `INSERT INTO broadcasts (admin_id, segment, title, body, sent_count) VALUES ($1,$2,$3,$4,$5)`,
    [req.user.id, segment, title, body, result.rowCount]
  );

  logger.info(`Platform admin ${req.user.id} sent broadcast to ${segment}: ${result.rowCount} users`);
  ApiResponse.success({ sentCount: result.rowCount, segment }, 'Notification sent').send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/notifications/history?page=1&limit=20
// ---------------------------------------------------------------------------
const getBroadcastHistory = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const page = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(10, Math.max(1, parseInt(req.query.limit, 10) || 10));
  const offset = (page - 1) * limit;

  const countRes = await queryRead('SELECT COUNT(*)::int AS total FROM broadcasts');
  const rows = await queryRead(
    `SELECT b.id, b.segment, b.title, b.body, b.sent_count, b.created_at,
            u.name AS admin_name
     FROM broadcasts b LEFT JOIN users u ON b.admin_id = u.id
     ORDER BY b.created_at DESC LIMIT $1 OFFSET $2`,
    [limit, offset]
  );

  ApiResponse.success({
    broadcasts: rows.rows,
    total: countRes.rows[0].total,
    page,
    totalPages: Math.ceil(countRes.rows[0].total / limit),
  }, 'Broadcast history').send(res);
});

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
// GET /api/platform-admin/config
// ---------------------------------------------------------------------------
const getAppConfig = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const result = await queryRead(
    `SELECT key, value, description FROM settings
     WHERE key IN ('platform_commission_driver','platform_commission_passenger')`
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
  ];

  const applied = [];
  for (const [key, value] of Object.entries(updates)) {
    if (!allowedKeys.includes(key)) continue;
    const strVal = String(value).trim();

    if (key === 'platform_commission_driver' || key === 'platform_commission_passenger') {
      const num = parseFloat(strVal);
      if (isNaN(num) || num < 0 || num > 100) {
        throw ApiError.badRequest(`${key} must be a number between 0 and 100`);
      }
    }
    await pool.query(
      `INSERT INTO settings (key, value, updated_at) VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      [key, strVal]
    );
    applied.push(key);
  }

  logger.info(`Platform admin ${req.user.id} updated config: ${applied.join(', ')}`);
  ApiResponse.success({ updated: applied }, 'Config updated').send(res);
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
// GET /api/platform-admin/daily-stats?days=180
// Rolling queue — one row per day, always last 180 days
// ---------------------------------------------------------------------------
const getDailyStats = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const days = Math.min(365, Math.max(1, parseInt(req.query.days, 10) || 180));

  let result;
  try {
    result = await queryRead(
      `SELECT stat_date, new_users, new_trips, completed_trips, cancelled_trips,
              new_bookings, confirmed_bookings, cancelled_bookings, upcoming_trips, active_drivers
       FROM daily_stats
       WHERE stat_date >= CURRENT_DATE - make_interval(days => $1)
       ORDER BY stat_date DESC`,
      [days]
    );
  } catch (err) {
    if (err.code === '42P01') {
      return ApiResponse.success({ stats: [], days_filter: days }, 'Migration 053 pending').send(res);
    }
    throw err;
  }

  ApiResponse.success({ stats: result.rows, days_filter: days }, 'Daily stats').send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/export-csv?days=180
// Downloads CSV of daily stats
// ---------------------------------------------------------------------------
const exportStatsCsv = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const days = Math.min(365, Math.max(1, parseInt(req.query.days, 10) || 180));

  let rows;
  try {
    const result = await queryRead(
      `SELECT stat_date, new_users, new_trips, completed_trips, cancelled_trips,
              new_bookings, confirmed_bookings, cancelled_bookings, upcoming_trips, active_drivers
       FROM daily_stats
       WHERE stat_date >= CURRENT_DATE - make_interval(days => $1)
       ORDER BY stat_date ASC`,
      [days]
    );
    rows = result.rows;
  } catch (err) {
    if (err.code === '42P01') {
      rows = [];
    } else {
      throw err;
    }
  }

  const header = 'Date,New Users,New Trips,Completed Trips,Cancelled Trips,New Bookings,Confirmed Bookings,Cancelled Bookings,Upcoming Trips,Active Drivers';
  const csvRows = rows.map(r => {
    const d = r.stat_date instanceof Date ? r.stat_date.toISOString().slice(0, 10) : String(r.stat_date).slice(0, 10);
    return `${d},${r.new_users},${r.new_trips},${r.completed_trips},${r.cancelled_trips},${r.new_bookings},${r.confirmed_bookings},${r.cancelled_bookings},${r.upcoming_trips},${r.active_drivers}`;
  });
  const csv = [header, ...csvRows].join('\n');

  res.setHeader('Content-Type', 'text/csv');
  res.setHeader('Content-Disposition', `attachment; filename="luharide-stats-${days}d.csv"`);
  res.send(csv);
});

// ===========================================================================
// PHASE 3 — Union FCM Management
// ===========================================================================

// ---------------------------------------------------------------------------
// GET /api/platform-admin/union-fcm
// ---------------------------------------------------------------------------
const getUnionFcmSettings = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const globalRes = await queryRead(
    `SELECT value FROM settings WHERE key = 'fcm_global_union_rides'`
  );
  const globalEnabled = (globalRes.rows[0]?.value ?? 'true') === 'true';

  const unionsRes = await queryRead(
    `SELECT id, name, fcm_enabled, status
     FROM unions
     WHERE status = 'approved'
     ORDER BY name ASC`
  );

  ApiResponse.success({
    globalEnabled,
    unions: unionsRes.rows,
  }, 'Union FCM settings').send(res);
});

// ---------------------------------------------------------------------------
// PATCH /api/platform-admin/union-fcm/global  { enabled: true/false }
// ---------------------------------------------------------------------------
const toggleGlobalUnionFcm = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { enabled } = req.body || {};
  if (typeof enabled !== 'boolean') {
    throw ApiError.badRequest('enabled must be true or false');
  }

  await pool.query(
    `INSERT INTO settings (key, value, description, updated_at)
     VALUES ('fcm_global_union_rides', $1, 'Global on/off for FCM push when unions create rides', NOW())
     ON CONFLICT (key) DO UPDATE SET value = $1, updated_at = NOW()`,
    [String(enabled)]
  );

  await pool.query(
    `UPDATE unions SET fcm_enabled = $1 WHERE status = 'approved'`,
    [enabled]
  );

  const unionsRes = await pool.query(
    `SELECT id, name, fcm_enabled, status FROM unions WHERE status = 'approved' ORDER BY name ASC`
  );

  logger.info(`Platform admin ${req.user.id} set global union FCM to ${enabled} (all ${unionsRes.rowCount} unions updated)`);
  ApiResponse.success({ globalEnabled: enabled, unions: unionsRes.rows }, 'Global FCM setting updated').send(res);
});

// ---------------------------------------------------------------------------
// PATCH /api/platform-admin/union-fcm/:unionId  { enabled: true/false }
// ---------------------------------------------------------------------------
const toggleUnionFcm = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { unionId } = req.params;
  const { enabled } = req.body || {};
  if (typeof enabled !== 'boolean') {
    throw ApiError.badRequest('enabled must be true or false');
  }

  const result = await pool.query(
    `UPDATE unions SET fcm_enabled = $1 WHERE id = $2 AND status = 'approved' RETURNING id, name, fcm_enabled`,
    [enabled, unionId]
  );
  if (result.rowCount === 0) {
    throw ApiError.notFound('Union not found or not approved');
  }

  logger.info(`Platform admin ${req.user.id} set FCM for union ${unionId} to ${enabled}`);
  ApiResponse.success(result.rows[0], 'Union FCM setting updated').send(res);
});

// ---------------------------------------------------------------------------
// GET /api/platform-admin/db-health
// ---------------------------------------------------------------------------
const getDbHealth = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  const [tableStats, indexUsage, poolStats, dbSize] = await Promise.all([
    queryRead(`
      SELECT relname AS table_name,
        n_live_tup::int AS live_rows,
        n_dead_tup::int AS dead_rows,
        pg_size_pretty(pg_total_relation_size(relid)) AS total_size
      FROM pg_stat_user_tables
      ORDER BY n_live_tup DESC
      LIMIT 30
    `),
    queryRead(`
      SELECT indexrelname AS index_name,
        relname AS table_name,
        idx_scan::int AS scans,
        pg_size_pretty(pg_relation_size(indexrelid)) AS size
      FROM pg_stat_user_indexes
      ORDER BY idx_scan DESC
      LIMIT 20
    `),
    queryRead(`SELECT * FROM pg_stat_activity WHERE datname = current_database() AND state IS NOT NULL`),
    queryRead(`SELECT pg_size_pretty(pg_database_size(current_database())) AS db_size`),
  ]);

  ApiResponse.success({
    dbSize: dbSize.rows[0]?.db_size,
    tables: tableStats.rows,
    topIndexes: indexUsage.rows,
    activeConnections: poolStats.rowCount,
    pool: { total: pool.totalCount, idle: pool.idleCount, waiting: pool.waitingCount },
  }, 'Database health').send(res);
});

module.exports = {
  getDashboard,
  getUsers,
  getUserDetail,
  toggleUserActive,
  getTrips,
  getTripDetail,
  cancelTrip,
  getRevenueOverview,
  sendBulkNotification,
  getBroadcastHistory,
  getComplaints,
  getComplaintDetail,
  resolveComplaint,
  getAppConfig,
  updateAppConfig,
  submitComplaint,
  getMyComplaints,
  getDailyStats,
  exportStatsCsv,
  getUnionFcmSettings,
  toggleGlobalUnionFcm,
  toggleUnionFcm,
  getDbHealth,
};
