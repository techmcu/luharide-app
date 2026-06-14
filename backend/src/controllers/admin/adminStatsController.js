const { pool, queryRead } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');

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
  getDailyStats,
  exportStatsCsv,
  getRevenueOverview,
  getDbHealth,
};
