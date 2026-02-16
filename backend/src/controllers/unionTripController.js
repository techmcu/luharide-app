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

  // Verify driver belongs to this union admin's union
  const driverCheck = await pool.query(
    `SELECT u.id, u.name, u.role 
     FROM users u
     WHERE u.id = $1 AND u.role = 'driver'`,
    [driver_id]
  );

  if (driverCheck.rows.length === 0) {
    throw ApiError.badRequest('Driver not found or invalid');
  }

  // TODO: Add union membership check when union system is implemented
  // For now, union admin can create trips for any driver

  // Store as UTC literal (same as driver createTrip) so passenger sees correct time
  const departureDate = new Date(departure_time);
  const arrivalDate = new Date(departureDate.getTime() + 2 * 60 * 60 * 1000);
  const departureStr = departureDate.toISOString().slice(0, 19).replace('T', ' ');
  const arrivalStr = arrivalDate.toISOString().slice(0, 19).replace('T', ' ');

  // Create trip
  const result = await pool.query(
    `INSERT INTO trips (
      driver_id, 
      from_location, 
      to_location, 
      departure_time, 
      arrival_time,
      fare_per_seat,
      total_seats,
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
 * Get all trips for drivers in union
 * GET /api/union/trips
 */
const getUnionTrips = asyncHandler(async (req, res) => {
  const unionAdminId = req.user.id;
  const { status } = req.query;

  // TODO: Filter by union membership when union system is implemented
  // For now, return all trips

  let query = `
    SELECT t.*, u.name as driver_name, u.email as driver_email
    FROM trips t
    LEFT JOIN users u ON t.driver_id = u.id
    WHERE 1=1
  `;

  const params = [];

  if (status) {
    query += ` AND t.status = $1`;
    params.push(status);
  }

  query += ` ORDER BY t.departure_time DESC`;

  const result = await pool.query(query, params);

  ApiResponse.success(
    { trips: result.rows, count: result.rows.length },
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
