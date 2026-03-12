const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

/**
 * Create trip for a driver in union (Union Admin only)
 * POST /api/union/trips
 */
const createTripForDriver = asyncHandler(async (req, res) => {
  const {
    driver_id,
    from_location,
    to_location,
    departure_time,
    fare_per_seat,
    total_seats = 7,
    vehicle_number,
    stops = []
  } = req.body;

  const unionAdminId = req.user.id;

  // Resolve this admin's union
  const unionRes = await pool.query(
    `SELECT ua.union_id FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [unionAdminId]
  );
  if (unionRes.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }
  const unionId = unionRes.rows[0].union_id;

  // Verify the driver exists and has the driver role
  const driverCheck = await pool.query(
    `SELECT u.id, u.name, u.role FROM users u WHERE u.id = $1 AND u.role = 'driver'`,
    [driver_id]
  );
  if (driverCheck.rows.length === 0) {
    throw ApiError.badRequest('Driver not found or user does not have driver role');
  }

  // Soft guard: warn but allow if driver is not yet linked to this union in union_admins.
  // A stricter check can be added once a proper union_drivers <-> users link table exists.
  logger.info(`Union ${unionId} admin ${unionAdminId} creating trip for driver ${driver_id}`);

  // Store as UTC literal (same as driver createTrip) so passenger sees correct time
  const departureDate = new Date(departure_time);
  const arrivalDate = new Date(departureDate.getTime() + 2 * 60 * 60 * 1000);
  const departureStr = departureDate.toISOString().slice(0, 19).replace('T', ' ');
  const arrivalStr = arrivalDate.toISOString().slice(0, 19).replace('T', ' ');

  // Create trip (DB uses total_capacity, not total_seats)
  const result = await pool.query(
    `INSERT INTO trips (
      driver_id, 
      from_location, 
      to_location, 
      departure_time, 
      arrival_time,
      fare_per_seat,
      total_capacity,
      available_seats,
      vehicle_number,
      stops,
      status
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
    RETURNING *`,
    [
      driver_id,
      from_location,
      to_location,
      departureStr,
      arrivalStr,
      fare_per_seat,
      total_seats,
      total_seats,
      vehicle_number,
      JSON.stringify(stops),
      'scheduled'
    ]
  );

  const trip = result.rows[0];

  logger.info(`Trip created by union admin ${unionAdminId} for driver ${driver_id}: ${trip.id}`);

  ApiResponse.created(
    { trip },
    'Trip created successfully for driver'
  ).send(res);
});

/**
 * Get trips for drivers in this union admin's union.
 * GET /api/union/trips?status=scheduled&page=1&limit=50
 *
 * Scoped to the caller's approved union. Paginated to prevent full-table scans.
 */
const getUnionTrips = asyncHandler(async (req, res) => {
  const unionAdminId = req.user.id;
  const { status } = req.query;
  const page  = Math.max(1, parseInt(req.query.page, 10) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit, 10) || 50));
  const offset = (page - 1) * limit;

  // Resolve this admin's union — ensures scoped data, not a global dump
  const unionRes = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [unionAdminId]
  );

  if (unionRes.rows.length === 0) {
    return ApiResponse.success(
      { trips: [], count: 0, page, limit },
      'No approved union found'
    ).send(res);
  }

  const unionId = unionRes.rows[0].union_id;

  // Scope to drivers belonging to this union via union_admins → union_drivers link.
  // union_drivers.phone is used as the join key since they may not have app accounts.
  // For now, fetch trips created by any driver whose app account is linked to this union.
  const params = [unionId, limit, offset];
  let statusClause = '';
  if (status) {
    params.push(status);
    statusClause = `AND t.status = $${params.length}`;
  }

  const result = await pool.query(
    `SELECT t.id, t.from_location, t.to_location, t.departure_time, t.arrival_time,
            t.fare_per_seat, t.total_capacity, t.available_seats, t.vehicle_number,
            t.status, t.stops, t.created_at,
            u.name AS driver_name, u.email AS driver_email, u.phone AS driver_phone
     FROM trips t
     LEFT JOIN users u ON t.driver_id = u.id
     WHERE t.driver_id IN (
       SELECT DISTINCT user_id FROM union_admins WHERE union_id = $1
       UNION
       SELECT driver_id FROM trips WHERE driver_id IN (
         SELECT user_id FROM union_admins WHERE union_id = $1
       )
     )
     ${statusClause}
     ORDER BY t.departure_time DESC
     LIMIT $2 OFFSET $3`,
    params
  );

  const trips = result.rows.map((t) => ({
    ...t,
    total_seats: t.total_capacity ?? 0,
    available_seats: t.available_seats ?? t.total_capacity ?? 0
  }));

  ApiResponse.success(
    { trips, count: trips.length, page, limit },
    'Union trips retrieved'
  ).send(res);
});

/**
 * Union admin dashboard – simple counts
 * GET /api/union/dashboard
 */
const getDashboardStats = asyncHandler(async (req, res) => {
  const [tripsRes, bookingsRes, driversRes] = await Promise.all([
    pool.query('SELECT COUNT(*)::int AS count FROM trips'),
    pool.query("SELECT COUNT(*)::int AS count FROM bookings WHERE status IN ('confirmed', 'pending')"),
    pool.query(
      "SELECT COUNT(DISTINCT user_id)::int AS count FROM driver_verification_requests WHERE status = 'approved'"
    )
  ]);

  ApiResponse.success(
    {
      total_trips: tripsRes.rows[0].count,
      total_bookings: bookingsRes.rows[0].count,
      drivers_verified: driversRes.rows[0].count
    },
    'Dashboard stats'
  ).send(res);
});

module.exports = {
  createTripForDriver,
  getUnionTrips,
  getDashboardStats
};
