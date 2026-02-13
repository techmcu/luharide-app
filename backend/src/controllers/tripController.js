const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

/**
 * Create a new trip (Driver only)
 * POST /api/trips
 */
const createTrip = asyncHandler(async (req, res) => {
  const {
    from_location,
    to_location,
    departure_time,
    fare_per_seat,
    total_seats: bodySeats,
    vehicle_number: bodyVehicleNumber,
    stops = [],
    require_approval = true
  } = req.body;

  const driverId = req.user.id;

  // Use verified vehicle capacity and registration when driver is approved (no manual override)
  let totalSeats = bodySeats != null ? parseInt(bodySeats) : 7;
  let vehicleNumber = bodyVehicleNumber || '';
  const verif = await pool.query(
    `SELECT vehicle_capacity, vehicle_registration
     FROM driver_verification_requests
     WHERE user_id = $1 AND status = 'approved'
     ORDER BY updated_at DESC LIMIT 1`,
    [driverId]
  );
  if (verif.rows[0]) {
    const cap = verif.rows[0].vehicle_capacity;
    if (cap != null && cap > 0) totalSeats = cap;
    if (verif.rows[0].vehicle_registration) vehicleNumber = verif.rows[0].vehicle_registration;
  }

  // Calculate estimated arrival (for now, add 2 hours)
  const departureDate = new Date(departure_time);
  const arrivalDate = new Date(departureDate.getTime() + 2 * 60 * 60 * 1000);

  const useRequireApproval = require_approval === false ? false : true;
  let result;

  try {
    result = await pool.query(
      `INSERT INTO trips (
        driver_id, from_location, to_location, departure_time, arrival_time,
        fare_per_seat, total_seats, total_capacity, available_seats,
        vehicle_number, stops, status, require_approval
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
      RETURNING *`,
      [
        driverId, from_location, to_location, departure_time, arrivalDate,
        fare_per_seat, totalSeats, totalSeats, totalSeats,
        vehicleNumber, JSON.stringify(stops), 'scheduled', useRequireApproval
      ]
    );
  } catch (err) {
    if (err.code === '42703' || err.message?.includes('require_approval')) {
      result = await pool.query(
        `INSERT INTO trips (
          driver_id, from_location, to_location, departure_time, arrival_time,
          fare_per_seat, total_seats, total_capacity, available_seats,
          vehicle_number, stops, status
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING *`,
        [
          driverId, from_location, to_location, departure_time, arrivalDate,
          fare_per_seat, totalSeats, totalSeats, totalSeats,
          vehicleNumber, JSON.stringify(stops), 'scheduled'
        ]
      );
    } else {
      throw err;
    }
  }

  const trip = result.rows[0];

  logger.info(`Trip created: ${trip.id} by driver ${driverId}`);

  ApiResponse.created(
    { trip },
    'Trip created successfully'
  ).send(res);
});

/**
 * Search trips
 * GET /api/trips/search?from=Dehradun&to=Haridwar&date=2026-02-12
 */
const searchTrips = asyncHandler(async (req, res) => {
  const { from, to, date } = req.query;

  if (!from || !to || !date) {
    throw ApiError.badRequest('from, to, and date are required');
  }

  // Parse date to get start and end of day
  const searchDate = new Date(date);
  const startOfDay = new Date(searchDate.setHours(0, 0, 0, 0));
  const endOfDay = new Date(searchDate.setHours(23, 59, 59, 999));

  const result = await pool.query(
    `SELECT 
      t.*,
      u.name as driver_name,
      u.email as driver_email,
      u.phone as driver_phone,
      u.driver_verification_status as driver_verified
    FROM trips t
    LEFT JOIN users u ON t.driver_id = u.id
    WHERE 
      LOWER(t.from_location) LIKE LOWER($1)
      AND LOWER(t.to_location) LIKE LOWER($2)
      AND t.departure_time >= $3
      AND t.departure_time <= $4
      AND t.status = 'scheduled'
      AND t.available_seats > 0
    ORDER BY t.departure_time ASC`,
    [`%${from}%`, `%${to}%`, startOfDay, endOfDay]
  );

  const trips = result.rows.map(trip => ({
    id: trip.id,
    from_location: trip.from_location,
    to_location: trip.to_location,
    departure_time: trip.departure_time,
    arrival_time: trip.arrival_time,
    fare_per_seat: trip.fare_per_seat,
    available_seats: trip.available_seats,
    total_seats: trip.total_seats,
    vehicle_number: trip.vehicle_number,
    stops: trip.stops,
    status: trip.status,
    driver: {
      id: trip.driver_id,
      name: trip.driver_name,
      email: trip.driver_email,
      phone: trip.driver_phone,
      isVerified: trip.driver_verified === 'approved'
    }
  }));

  ApiResponse.success(
    { trips, count: trips.length },
    'Trips found'
  ).send(res);
});

/**
 * Get booked/pending seats for a trip (for seat selection UI)
 * GET /api/trips/:id/booked-seats
 * Returns which seats are confirmed vs pending - prevents showing wrong availability
 */
const getTripBookedSeats = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;

  const tripCheck = await pool.query(
    'SELECT id, total_seats FROM trips WHERE id = $1 AND status = $2',
    [tripId, 'scheduled']
  );

  if (tripCheck.rows.length === 0) {
    throw ApiError.notFound('Trip not found or not available');
  }

  const result = await pool.query(
    `SELECT seat_numbers, status FROM bookings 
     WHERE trip_id = $1 AND status IN ('confirmed', 'pending')`,
    [tripId]
  );

  const booked = [];
  const pending = [];

  for (const row of result.rows) {
    const seats = row.seat_numbers || [];
    for (const s of seats) {
      const num = typeof s === 'number' ? s : parseInt(s, 10);
      if (!Number.isNaN(num) && num >= 1) {
        if (row.status === 'confirmed') {
          booked.push(num);
        } else {
          pending.push(num);
        }
      }
    }
  }

  const bookedSet = new Set(booked);
  const pendingSet = new Set(pending);
  const allTakenSet = new Set([...booked, ...pending]);
  const totalSeats = tripCheck.rows[0].total_seats;
  const availableCount = Math.max(0, totalSeats - allTakenSet.size);

  ApiResponse.success(
    {
      booked: [...bookedSet].sort((a, b) => a - b),
      pending: [...pendingSet].sort((a, b) => a - b),
      total_seats: totalSeats,
      available_seats: Math.max(0, availableCount),
    },
    'Booked seats'
  ).send(res);
});

/**
 * Get trip details (includes booked & pending seats for seat selection UI)
 * GET /api/trips/:id
 */
const getTripDetails = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const result = await pool.query(
    `SELECT 
      t.*,
      u.name as driver_name,
      u.email as driver_email,
      u.phone as driver_phone,
      u.driver_verification_status as driver_verified
    FROM trips t
    LEFT JOIN users u ON t.driver_id = u.id
    WHERE t.id = $1`,
    [id]
  );

  if (result.rows.length === 0) {
    throw ApiError.notFound('Trip not found');
  }

  const trip = result.rows[0];

  // Fetch booked & pending seats for seat selection
  const bookingsResult = await pool.query(
    `SELECT seat_numbers, status FROM bookings 
     WHERE trip_id = $1 AND status IN ('confirmed', 'pending')`,
    [id]
  );

  const booked = [];
  const pending = [];
  for (const row of bookingsResult.rows) {
    const seats = row.seat_numbers || [];
    for (const s of seats) {
      const num = typeof s === 'number' ? s : parseInt(s, 10);
      if (!Number.isNaN(num) && num >= 1) {
        if (row.status === 'confirmed') {
          booked.push(num);
        } else {
          pending.push(num);
        }
      }
    }
  }

  const bookedSet = new Set(booked);
  const pendingSet = new Set(pending);
  const allTakenSet = new Set([...booked, ...pending]);
  const totalSeats = trip.total_seats;
  const availableSeats = Math.max(0, totalSeats - allTakenSet.size);

  ApiResponse.success(
    {
      trip: {
        id: trip.id,
        from_location: trip.from_location,
        to_location: trip.to_location,
        departure_time: trip.departure_time,
        arrival_time: trip.arrival_time,
        fare_per_seat: trip.fare_per_seat,
        available_seats: availableSeats,
        total_seats: trip.total_seats,
        vehicle_number: trip.vehicle_number,
        stops: trip.stops,
        status: trip.status,
        driver: {
          id: trip.driver_id,
          name: trip.driver_name,
          email: trip.driver_email,
          phone: trip.driver_phone,
          isVerified: trip.driver_verified === 'approved'
        }
      },
      booked_seats: [...bookedSet].sort((a, b) => a - b),
      pending_seats: [...pendingSet].sort((a, b) => a - b),
    },
    'Trip details'
  ).send(res);
});

/**
 * Get my trips (Driver only)
 * GET /api/trips/my-trips
 * Includes pending_requests_count for each trip so driver can see which need approval
 */
const getMyTrips = asyncHandler(async (req, res) => {
  const driverId = req.user.id;
  const { status } = req.query;

  let query = `
    SELECT t.*,
      (SELECT COUNT(*) FROM bookings b 
       WHERE b.trip_id = t.id AND b.status = 'pending') as pending_requests_count
    FROM trips t
    WHERE t.driver_id = $1
  `;

  const params = [driverId];

  if (status) {
    query += ` AND t.status = $2`;
    params.push(status);
  }

  query += ` ORDER BY pending_requests_count DESC, t.departure_time DESC`;

  const result = await pool.query(query, params);

  const trips = result.rows.map(row => ({
    ...row,
    pending_requests_count: parseInt(row.pending_requests_count, 10) || 0
  }));

  ApiResponse.success(
    { trips, count: trips.length },
    'Trips retrieved'
  ).send(res);
});

/**
 * Get location suggestions
 * GET /api/trips/locations?q=Deh
 */
const getLocationSuggestions = asyncHandler(async (req, res) => {
  const { q } = req.query;

  if (!q || q.length < 2) {
    return ApiResponse.success({ suggestions: [] }, 'No suggestions').send(res);
  }

  // Get unique locations from trips
  const result = await pool.query(
    `SELECT DISTINCT location
    FROM (
      SELECT from_location as location FROM trips
      UNION
      SELECT to_location as location FROM trips
    ) as locations
    WHERE LOWER(location) LIKE LOWER($1)
    ORDER BY location
    LIMIT 10`,
    [`%${q}%`]
  );

  // Add some default Uttarakhand locations if no results
  const defaultLocations = [
    'Dehradun',
    'Haridwar',
    'Rishikesh',
    'Mussoorie',
    'Nainital',
    'Almora',
    'Haldwani',
    'Roorkee',
    'Rudrapur',
    'Kashipur'
  ].filter(loc => loc.toLowerCase().includes(q.toLowerCase()));

  const suggestions = result.rows.length > 0 
    ? result.rows.map(row => row.location)
    : defaultLocations;

  ApiResponse.success(
    { suggestions },
    'Location suggestions'
  ).send(res);
});

/**
 * Get trip bookings (Driver only - for their own trips)
 * GET /api/trips/:id/bookings
 */
const getTripBookings = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  const driverId = req.user.id;

  // Verify trip belongs to driver
  const tripCheck = await pool.query(
    'SELECT id FROM trips WHERE id = $1 AND driver_id = $2',
    [tripId, driverId]
  );

  if (tripCheck.rows.length === 0) {
    throw ApiError.forbidden('You can only view bookings for your own trips');
  }

  const result = await pool.query(
    `SELECT 
      b.id,
      b.trip_id,
      b.passenger_id,
      b.seat_numbers,
      b.status,
      b.total_amount,
      b.created_at,
      u.name as passenger_name,
      u.email as passenger_email,
      u.phone as passenger_phone
    FROM bookings b
    JOIN users u ON b.passenger_id = u.id
    WHERE b.trip_id = $1 AND b.status IN ('confirmed', 'pending')
    ORDER BY b.created_at ASC`,
    [tripId]
  );

  const bookings = result.rows.map(row => ({
    id: row.id,
    trip_id: row.trip_id,
    passenger_id: row.passenger_id,
    seat_numbers: row.seat_numbers,
    status: row.status,
    total_amount: parseFloat(row.total_amount),
    created_at: row.created_at,
    passenger: {
      id: row.passenger_id,
      name: row.passenger_name,
      email: row.passenger_email,
      phone: row.passenger_phone
    }
  }));

  ApiResponse.success(
    { bookings },
    'Bookings retrieved'
  ).send(res);
});

/**
 * Delete trip (Driver only) - BlaBlaCar style
 * Only allowed when: NO confirmed or pending bookings
 * DELETE /api/trips/:id
 */
const deleteTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  const driverId = req.user.id;

  const tripResult = await pool.query(
    'SELECT * FROM trips WHERE id = $1 AND driver_id = $2',
    [tripId, driverId]
  );

  if (tripResult.rows.length === 0) {
    throw ApiError.notFound('Trip not found');
  }

  const bookingsCheck = await pool.query(
    `SELECT status, seat_numbers FROM bookings 
     WHERE trip_id = $1 AND status IN ('confirmed', 'pending')`,
    [tripId]
  );

  if (bookingsCheck.rows.length > 0) {
    const confirmedCount = bookingsCheck.rows.filter(r => r.status === 'confirmed').length;
    const pendingCount = bookingsCheck.rows.filter(r => r.status === 'pending').length;
    const msg = confirmedCount > 0
      ? `Cannot delete ride. ${confirmedCount} seat(s) are already booked. Passengers would be affected.`
      : `Cannot delete ride. ${pendingCount} booking request(s) are pending. Please accept or reject them first.`;
    throw ApiError.badRequest(msg);
  }

  await pool.query(
    'DELETE FROM bookings WHERE trip_id = $1',
    [tripId]
  );
  await pool.query(
    'DELETE FROM trips WHERE id = $1',
    [tripId]
  );

  logger.info(`Trip deleted: ${tripId} by driver ${driverId}`);

  ApiResponse.success(
    { deleted: true },
    'Ride deleted successfully'
  ).send(res);
});

module.exports = {
  createTrip,
  searchTrips,
  getTripDetails,
  getMyTrips,
  getLocationSuggestions,
  getTripBookings,
  getTripBookedSeats,
  deleteTrip
};
