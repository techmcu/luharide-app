const { pool, queryRead } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const { emitNotificationToUser } = require('../../socket/realtimeEmitter');

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

  // All queries run in parallel — single round-trip, no sequential waits
  const [userRes, tripsRes, bookingsRes, ratingsRes, reviewsRes, flagsRes] = await Promise.all([
    queryRead(
      `SELECT id, name, phone, email, role, is_active, is_verified,
              driver_verification_status, profile_image_url,
              bio, whatsapp_number, created_at, last_login, cancel_blocked_until
       FROM users WHERE id = $1`,
      [id]
    ),
    queryRead(
      `SELECT id, from_location, to_location, departure_time, status,
              fare_per_seat, available_seats, total_capacity, vehicle_number
       FROM trips WHERE driver_id = $1
       ORDER BY departure_time DESC LIMIT 20`,
      [id]
    ),
    queryRead(
      `SELECT b.id, b.trip_id, b.seat_numbers, b.status, b.total_amount, b.created_at,
              t.from_location, t.to_location, t.departure_time
       FROM bookings b
       JOIN trips t ON b.trip_id = t.id
       WHERE b.passenger_id = $1
       ORDER BY b.created_at DESC LIMIT 20`,
      [id]
    ),
    queryRead(
      `SELECT
         COUNT(*)::int AS total_ratings,
         ROUND(AVG(rating)::numeric, 1) AS avg_rating,
         COUNT(CASE WHEN rating >= 4 THEN 1 END)::int AS good_ratings,
         COUNT(CASE WHEN rating <= 2 THEN 1 END)::int AS low_ratings
       FROM ride_ratings WHERE rated_user_id = $1`,
      [id]
    ),
    queryRead(
      `SELECT r.id, r.from_user_id, r.rating, r.comment, r.from_role, r.trip_context, r.created_at, u.name AS from_name
       FROM ride_ratings r JOIN users u ON u.id = r.from_user_id
       WHERE r.rated_user_id = $1 ORDER BY r.created_at DESC LIMIT 20`,
      [id]
    ).catch(() => ({ rows: [] })),
    queryRead(
      `SELECT id, flag_type, reason, month_window, violation_count, blocked_until, created_at, resolved_at
       FROM driver_abuse_flags WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20`,
      [id]
    ).catch(() => ({ rows: [] })),
  ]);

  if (userRes.rows.length === 0) throw ApiError.notFound('User not found');

  ApiResponse.success({
    user: userRes.rows[0],
    trips: tripsRes.rows,
    bookings: bookingsRes.rows,
    ratings: ratingsRes.rows[0],
    recent_reviews: reviewsRes.rows,
    abuse_flags: flagsRes.rows,
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
// GET /api/platform-admin/flagged-drivers
// ---------------------------------------------------------------------------
const getFlaggedDrivers = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);

  let rows = [];
  try {
    const result = await queryRead(
      `SELECT f.id, f.user_id, f.flag_type, f.reason, f.month_window,
              f.violation_count, f.blocked_until, f.created_at, f.resolved_at,
              u.name AS driver_name, u.phone AS driver_phone, u.email AS driver_email,
              u.cancel_blocked_until,
              (SELECT ROUND(AVG(r.rating)::numeric, 2) FROM ride_ratings r WHERE r.rated_user_id = f.user_id) AS avg_rating,
              (SELECT COUNT(*)::int FROM ride_ratings r WHERE r.rated_user_id = f.user_id) AS total_ratings
       FROM driver_abuse_flags f
       JOIN users u ON u.id = f.user_id
       WHERE f.resolved_at IS NULL
       ORDER BY f.created_at DESC
       LIMIT 100`
    );
    rows = result.rows;
  } catch (e) {
    if (e.code !== '42P01') throw e;
  }

  ApiResponse.success({ flagged_drivers: rows }, 'Flagged drivers').send(res);
});

// ---------------------------------------------------------------------------
// PATCH /api/platform-admin/flagged-drivers/:id/resolve
// ---------------------------------------------------------------------------
const resolveFlaggedDriver = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;
  const adminId = req.user.id;

  try {
    const result = await pool.query(
      `UPDATE driver_abuse_flags SET resolved_at = NOW(), resolved_by = $1
       WHERE id = $2 AND resolved_at IS NULL RETURNING user_id`,
      [adminId, id]
    );
    if (result.rows.length === 0) {
      throw ApiError.notFound('Flag not found or already resolved');
    }
  } catch (e) {
    if (e.code === '42P01') throw ApiError.notFound('Flagging system not set up');
    throw e;
  }

  ApiResponse.success({ resolved: true }, 'Flag resolved').send(res);
});

// ---------------------------------------------------------------------------
// POST /api/platform-admin/users/:id/ban   { reason, duration_days? }
// ---------------------------------------------------------------------------
const banDriver = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;
  const { reason, duration_days: rawDays } = req.body;

  if (!reason || typeof reason !== 'string' || reason.trim().length < 3) {
    throw ApiError.badRequest('Reason is required (min 3 characters)');
  }

  const days = Number(rawDays);
  const isPermanent = !rawDays || Number.isNaN(days) || days <= 0;
  const blockedUntil = isPermanent
    ? '2099-12-31T00:00:00.000Z'
    : new Date(Date.now() + days * 24 * 60 * 60 * 1000).toISOString();

  await pool.query(
    `UPDATE users SET cancel_blocked_until = $2 WHERE id = $1`,
    [id, blockedUntil]
  );

  const monthKey = new Date().toISOString().slice(0, 7);
  try {
    await pool.query(
      `INSERT INTO driver_abuse_flags (user_id, flag_type, reason, month_window, violation_count, blocked_until)
       VALUES ($1, 'admin_manual_ban', $2, $3, 0, $4)`,
      [id, `Admin ban: ${reason.trim().slice(0, 500)}`, monthKey, blockedUntil]
    );
  } catch (e) {
    if (e.code !== '42P01') logger.warn('Admin ban flag insert failed:', e.message);
  }

  const label = isPermanent ? 'permanently' : `for ${days} days`;
  logger.info(`Admin ${req.user.id} banned driver ${id} ${label}: ${reason}`);

  try {
    const n = await pool.query(
      `INSERT INTO notifications (user_id, type, title, body, data)
       VALUES ($1, 'account_warning', 'Account restricted by admin',
         $2, $3::jsonb)
       RETURNING id, user_id, type, title, body, data, created_at, is_read`,
      [
        id,
        isPermanent
          ? 'Your account has been permanently restricted by the platform admin.'
          : `Your account has been restricted for ${days} days by the platform admin.`,
        JSON.stringify({ reason: reason.trim().slice(0, 200), blocked_until: blockedUntil }),
      ]
    );
    if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
  } catch (_) {}

  ApiResponse.success({ banned: true, blocked_until: blockedUntil }, `Driver banned ${label}`).send(res);
});

// ---------------------------------------------------------------------------
// POST /api/platform-admin/users/:id/unban
// ---------------------------------------------------------------------------
const unbanDriver = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;

  await pool.query(
    `UPDATE users SET cancel_blocked_until = NULL WHERE id = $1`,
    [id]
  );

  try {
    await pool.query(
      `UPDATE driver_abuse_flags SET resolved_at = NOW(), resolved_by = $1
       WHERE user_id = $2 AND resolved_at IS NULL`,
      [req.user.id, id]
    );
  } catch (_) {}

  logger.info(`Admin ${req.user.id} unbanned driver ${id}`);

  try {
    const n = await pool.query(
      `INSERT INTO notifications (user_id, type, title, body, data)
       VALUES ($1, 'account_warning', 'Account restriction lifted',
         'Your account restrictions have been removed. You can now create and manage rides again.',
         '{"reason":"admin_unban"}'::jsonb)
       RETURNING id, user_id, type, title, body, data, created_at, is_read`,
      [id]
    );
    if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
  } catch (_) {}

  ApiResponse.success({ unbanned: true }, 'Driver unbanned').send(res);
});

// ---------------------------------------------------------------------------
// DELETE /api/platform-admin/ratings/:id  — delete a fake/spam rating
// ---------------------------------------------------------------------------
const deleteRating = asyncHandler(async (req, res) => {
  ensurePlatformAdmin(req.user);
  const { id } = req.params;

  const result = await pool.query(
    `DELETE FROM ride_ratings WHERE id = $1 RETURNING id, rated_user_id`,
    [id]
  );
  if (result.rows.length === 0) throw ApiError.notFound('Rating not found');

  logger.info(`Admin ${req.user.id} deleted rating ${id} (rated_user: ${result.rows[0].rated_user_id})`);
  ApiResponse.success({ deleted: true }, 'Rating deleted').send(res);
});

module.exports = {
  getUsers,
  getUserDetail,
  toggleUserActive,
  getFlaggedDrivers,
  resolveFlaggedDriver,
  banDriver,
  unbanDriver,
  deleteRating,
};
