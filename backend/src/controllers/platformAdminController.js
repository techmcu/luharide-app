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

  const { rows } = await queryRead(`
    SELECT
      (SELECT COUNT(*)::int FROM users WHERE role = 'passenger')   AS passengers,
      (SELECT COUNT(*)::int FROM users WHERE role = 'driver')      AS drivers,
      (SELECT COUNT(*)::int FROM users WHERE role = 'union_admin') AS union_admins,
      (SELECT COUNT(*)::int FROM users)                            AS total_users,
      (SELECT COUNT(*)::int FROM trips)                            AS total_trips,
      (SELECT COUNT(*)::int FROM trips WHERE status = 'scheduled')   AS scheduled_trips,
      (SELECT COUNT(*)::int FROM trips WHERE status = 'in_progress') AS active_trips,
      (SELECT COUNT(*)::int FROM trips WHERE status = 'completed')   AS completed_trips,
      (SELECT COUNT(*)::int FROM trips WHERE status = 'cancelled')   AS cancelled_trips,
      (SELECT COUNT(*)::int FROM bookings WHERE status = 'confirmed') AS confirmed_bookings,
      (SELECT COUNT(*)::int FROM bookings WHERE status = 'pending')   AS pending_bookings,
      (SELECT COUNT(*)::int FROM bookings WHERE status = 'cancelled') AS cancelled_bookings,
      (SELECT COUNT(*)::int FROM trips WHERE departure_time::date = CURRENT_DATE) AS today_trips,
      (SELECT COUNT(*)::int FROM users WHERE created_at >= NOW() - INTERVAL '7 days') AS new_users_week,
      (SELECT COUNT(DISTINCT driver_id)::int FROM trips WHERE created_at >= NOW() - INTERVAL '30 days') AS active_drivers
  `);

  ApiResponse.success(rows[0], 'Dashboard stats').send(res);
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

    await client.query(
      `UPDATE trips SET status = 'cancelled', updated_at = NOW() WHERE id = $1`,
      [id]
    );

    const affectedBookings = await client.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
              cancellation_reason = $2
       WHERE id IN (
         SELECT id FROM bookings WHERE trip_id = $1 AND status IN ('pending', 'confirmed') FOR UPDATE
       )
       RETURNING passenger_id`,
      [id, reason || 'Cancelled by platform admin']
    );

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
  const validSegments = ['all', 'passenger', 'drivers', 'union_admins'];
  if (!segment || !validSegments.includes(segment)) {
    throw ApiError.badRequest(`segment must be one of: ${validSegments.join(', ')}`);
  }

  const roleFilter = segment === 'all' ? null
    : segment === 'drivers' ? 'driver'
    : segment === 'union_admins' ? 'union_admin'
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
     WHERE key IN ('maintenance_mode','maintenance_message','force_update_min_version',
                   'platform_commission_driver','platform_commission_passenger')`
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
    'maintenance_mode', 'maintenance_message', 'force_update_min_version',
    'platform_commission_driver', 'platform_commission_passenger',
  ];

  const applied = [];
  for (const [key, value] of Object.entries(updates)) {
    if (!allowedKeys.includes(key)) continue;
    await pool.query(
      `INSERT INTO settings (key, value, updated_at) VALUES ($1, $2, NOW())
       ON CONFLICT (key) DO UPDATE SET value = $2, updated_at = NOW()`,
      [key, String(value)]
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
// Public: GET /api/app-config  (no auth)
// ---------------------------------------------------------------------------
const getPublicAppConfig = asyncHandler(async (req, res) => {
  const result = await queryRead(
    `SELECT key, value FROM settings
     WHERE key IN ('maintenance_mode','maintenance_message','force_update_min_version')`
  );

  const config = {};
  for (const row of result.rows) {
    config[row.key] = row.value;
  }

  res.json({ success: true, data: config });
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
  getPublicAppConfig,
};
