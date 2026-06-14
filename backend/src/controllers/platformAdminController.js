const { pool, queryRead } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

const adminEmail = process.env.ADMIN_EMAIL
  ? process.env.ADMIN_EMAIL.toLowerCase().trim()
  : null;

function ensurePlatformAdmin(user) {
  const email = user?.email ? String(user.email).toLowerCase().trim() : null;
  if (!adminEmail || !email || email !== adminEmail) {
    throw ApiError.forbidden('Only platform admin can perform this action');
  }
}

// --- Sub-controllers ---------------------------------------------------------
const adminStatsController = require('./admin/adminStatsController');
const adminUserController = require('./admin/adminUserController');
const adminNotificationController = require('./admin/adminNotificationController');
const complaintController = require('./admin/complaintController');

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
      `UPDATE trips SET status = 'cancelled', cancelled_by = 'admin', updated_at = NOW(),
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

module.exports = {
  // Stats
  getDashboard: adminStatsController.getDashboard,
  getDailyStats: adminStatsController.getDailyStats,
  exportStatsCsv: adminStatsController.exportStatsCsv,
  getRevenueOverview: adminStatsController.getRevenueOverview,
  getDbHealth: adminStatsController.getDbHealth,
  // Users
  getUsers: adminUserController.getUsers,
  getUserDetail: adminUserController.getUserDetail,
  toggleUserActive: adminUserController.toggleUserActive,
  getFlaggedDrivers: adminUserController.getFlaggedDrivers,
  resolveFlaggedDriver: adminUserController.resolveFlaggedDriver,
  banDriver: adminUserController.banDriver,
  unbanDriver: adminUserController.unbanDriver,
  deleteRating: adminUserController.deleteRating,
  // Trips (inline)
  getTrips,
  getTripDetail,
  cancelTrip,
  // Notifications
  sendBulkNotification: adminNotificationController.sendBulkNotification,
  getBroadcastHistory: adminNotificationController.getBroadcastHistory,
  getUnionFcmSettings: adminNotificationController.getUnionFcmSettings,
  toggleGlobalUnionFcm: adminNotificationController.toggleGlobalUnionFcm,
  toggleUnionFcm: adminNotificationController.toggleUnionFcm,
  // Complaints & Config
  getComplaints: complaintController.getComplaints,
  getComplaintDetail: complaintController.getComplaintDetail,
  resolveComplaint: complaintController.resolveComplaint,
  submitComplaint: complaintController.submitComplaint,
  getMyComplaints: complaintController.getMyComplaints,
  getAppConfig: complaintController.getAppConfig,
  updateAppConfig: complaintController.updateAppConfig,
};
