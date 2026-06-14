const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const toTitleCase = require('../utils/titleCase');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function requireUuid(id) {
  if (!id || !UUID_RE.test(id)) throw ApiError.badRequest('Invalid trip ID');
}

// ── Sub-controllers ─────────────────────────────────────────────────────────
const {
  searchTrips,
  getTripBookedSeats,
  getRecentRoutes,
  saveRecentRoute,
  getLocationSuggestions,
} = require('./trip/tripSearchController');

const {
  startTrip,
  completeTrip,
  cancelTrip,
  deleteTrip,
} = require('./trip/tripLifecycleController');

// ── Create trip (Driver only) ───────────────────────────────────────────────
const createTrip = asyncHandler(async (req, res) => {
  const {
    from_location: rawFrom,
    to_location: rawTo,
    departure_time,
    fare_per_seat: rawFare,
    total_seats: bodySeats,
    vehicle_number: bodyVehicleNumber,
    stops = [],
    require_approval = true,
    route_id: rawRouteId,
    luggage_allowance_per_passenger: rawTripLuggage,
    estimated_duration_hours: rawDuration,
  } = req.body;

  const driverId = req.user.id;

  try {
    const blockCheck = await pool.query(
      `SELECT cancel_blocked_until FROM users WHERE id = $1`,
      [driverId]
    );
    if (blockCheck.rows[0]?.cancel_blocked_until && new Date(blockCheck.rows[0].cancel_blocked_until) > new Date()) {
      const until = new Date(blockCheck.rows[0].cancel_blocked_until);
      throw ApiError.badRequest(
        'You have cancelled too many rides recently. Please try again later.'
      );
    }
  } catch (e) {
    if (e.statusCode) throw e;
    if (e.code !== '42703') logger.warn('Create trip block check failed:', e.message);
  }

  const tripLuggage =
    rawTripLuggage != null && String(rawTripLuggage).trim() !== ''
      ? String(rawTripLuggage).trim().slice(0, 200)
      : null;

  const from_location = toTitleCase((rawFrom != null ? String(rawFrom).trim() : '').slice(0, 200));
  const to_location = toTitleCase((rawTo != null ? String(rawTo).trim() : '').slice(0, 200));
  if (!from_location || from_location.length < 2) {
    throw ApiError.badRequest('From location is required (at least 2 characters).');
  }
  if (!to_location || to_location.length < 2) {
    throw ApiError.badRequest('To location is required (at least 2 characters).');
  }
  if (from_location.toLowerCase().replace(/\s+/g, '') === to_location.toLowerCase().replace(/\s+/g, '')) {
    throw ApiError.badRequest('From and To location cannot be the same.');
  }
  const fare_per_seat = Number(rawFare);
  if (Number.isNaN(fare_per_seat) || fare_per_seat <= 0) {
    throw ApiError.badRequest('Fare per seat must be a positive number.');
  }

  const routeId = rawRouteId != null ? String(rawRouteId).trim() : null;

  let verif;
  try {
    verif = await pool.query(
      `SELECT vehicle_capacity, vehicle_registration
       FROM driver_verification_requests
       WHERE user_id = $1 AND status = 'approved'
       ORDER BY updated_at DESC LIMIT 1`,
      [driverId]
    );
  } catch (dbErr) {
    if (dbErr.code === '42P01' || dbErr.code === '42703') {
      logger.error('Create trip: driver_verification_requests missing or schema outdated', { code: dbErr.code, message: dbErr.message });
      throw ApiError.serviceUnavailable('Driver verification not set up. Please run database migrations (npm run migrate).');
    }
    throw dbErr;
  }

  if (!verif.rows[0]) {
    throw ApiError.forbidden('Complete driver verification first. Go to Profile → Become a Driver.');
  }

  const MAX_SEATS = 32;
  const cap = verif.rows[0].vehicle_capacity;
  let totalSeats = (cap != null && cap > 0) ? cap : 7;
  if (totalSeats > MAX_SEATS) totalSeats = MAX_SEATS;
  if (totalSeats < 2) totalSeats = 2;
  const bookableSeats = totalSeats - 1;
  const vehicleNumber = (verif.rows[0].vehicle_registration || bodyVehicleNumber || '').toString().trim().slice(0, 20);
  let vehicleModelId = null;
  try {
    const verif2 = await pool.query(
      `SELECT vehicle_model_id FROM driver_verification_requests WHERE user_id = $1 AND status = 'approved' ORDER BY updated_at DESC LIMIT 1`,
      [driverId]
    );
    if (verif2.rows[0] && verif2.rows[0].vehicle_model_id) vehicleModelId = verif2.rows[0].vehicle_model_id;
  } catch (_) {}

  const departureDate = new Date(departure_time);
  if (Number.isNaN(departureDate.getTime())) {
    throw ApiError.badRequest('Invalid departure_time. Use ISO 8601 format (e.g. with Z for UTC).');
  }
  if (departureDate.getTime() < Date.now()) {
    throw ApiError.badRequest('Departure time cannot be in the past');
  }
  const MIN_ADVANCE_MINUTES = 30;
  const minAdvanceMs = MIN_ADVANCE_MINUTES * 60 * 1000;
  if (departureDate.getTime() - Date.now() < minAdvanceMs) {
    throw ApiError.badRequest(
      `Ride departure must be at least ${MIN_ADVANCE_MINUTES} minutes from now.`
    );
  }
  const MIN_DURATION_HOURS = 1;
  const MAX_DURATION_HOURS = 12;
  const DEFAULT_DURATION_HOURS = 2;
  const estimatedDuration = rawDuration != null ? Number(rawDuration) : NaN;
  if (rawDuration != null && (Number.isNaN(estimatedDuration) || estimatedDuration < MIN_DURATION_HOURS || estimatedDuration > MAX_DURATION_HOURS)) {
    throw ApiError.badRequest(`Estimated travel time must be between ${MIN_DURATION_HOURS} and ${MAX_DURATION_HOURS} hours.`);
  }
  const durationHours = (!Number.isNaN(estimatedDuration) && estimatedDuration >= MIN_DURATION_HOURS && estimatedDuration <= MAX_DURATION_HOURS)
    ? estimatedDuration
    : DEFAULT_DURATION_HOURS;
  const arrivalDate = new Date(departureDate.getTime() + durationHours * 60 * 60 * 1000);

  const overlap = await pool.query(
    `SELECT id FROM trips
     WHERE driver_id = $1 AND status IN ('scheduled', 'in_progress')
       AND departure_time < $2::timestamp
       AND COALESCE(arrival_time, departure_time + INTERVAL '2 hours') > $3::timestamp
     LIMIT 1`,
    [driverId, arrivalDate.toISOString(), departureDate.toISOString()]
  );
  if (overlap.rows.length > 0) {
    throw ApiError.badRequest(
      'You already have another ride scheduled at this time. Complete or cancel it first.'
    );
  }

  const DAILY_RIDE_LIMIT = 4;
  try {
    const dailyCount = await pool.query(
      `SELECT COUNT(*)::int AS cnt FROM trips
       WHERE driver_id = $1 AND created_source = 'independent_driver'
         AND created_at >= CURRENT_DATE::timestamp
         AND created_at < (CURRENT_DATE + 1)::timestamp`,
      [driverId]
    );
    if ((dailyCount.rows[0]?.cnt || 0) >= DAILY_RIDE_LIMIT) {
      throw ApiError.badRequest(
        `You can create a maximum of ${DAILY_RIDE_LIMIT} rides per day. Please try again tomorrow.`
      );
    }
  } catch (e) {
    if (e.statusCode) throw e;
    logger.warn('Daily ride limit check failed:', e.message);
  }

  const MAX_FARE_PER_SEAT = 10000;
  const MIN_FARE_PER_SEAT = 10;
  if (fare_per_seat < MIN_FARE_PER_SEAT) {
    throw ApiError.badRequest(`Fare per seat must be at least ₹${MIN_FARE_PER_SEAT}.`);
  }
  if (fare_per_seat > MAX_FARE_PER_SEAT) {
    throw ApiError.badRequest(`Fare per seat cannot exceed ₹${MAX_FARE_PER_SEAT}.`);
  }

  const departureStr = departureDate.toISOString().slice(0, 19).replace('T', ' ');
  const arrivalStr = arrivalDate.toISOString().slice(0, 19).replace('T', ' ');

  const useRequireApproval = require_approval === false ? false : true;
  const stopsArray = Array.isArray(stops) ? stops : [];
  const stopsJson = JSON.stringify(stopsArray.map(s => (s != null ? String(s).trim() : '').slice(0, 200)));

  let result;
  const runInsert = (query, params) => pool.query(query, params);

  try {
    try {
      result = await runInsert(
        `INSERT INTO trips (
          driver_id, from_location, to_location, departure_time, arrival_time,
          fare_per_seat, total_capacity, available_seats,
          vehicle_number, vehicle_model_id, stops, status, require_approval, route_id,
          luggage_allowance_per_passenger, created_source, estimated_duration_hours
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
        RETURNING *`,
        [
          driverId, from_location, to_location, departureStr, arrivalStr,
          fare_per_seat, totalSeats, bookableSeats,
          vehicleNumber, vehicleModelId, stopsJson, 'scheduled', useRequireApproval, routeId,
          tripLuggage,
          'independent_driver', durationHours,
        ]
      );
    } catch (eCreated) {
      const emsg = (eCreated.message || '').toString();
      if (eCreated.code === '42703' && emsg.includes('estimated_duration_hours')) {
        result = await runInsert(
          `INSERT INTO trips (
            driver_id, from_location, to_location, departure_time, arrival_time,
            fare_per_seat, total_capacity, available_seats,
            vehicle_number, vehicle_model_id, stops, status, require_approval, route_id,
            luggage_allowance_per_passenger, created_source
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
          RETURNING *`,
          [
            driverId, from_location, to_location, departureStr, arrivalStr,
            fare_per_seat, totalSeats, bookableSeats,
            vehicleNumber, vehicleModelId, stopsJson, 'scheduled', useRequireApproval, routeId,
            tripLuggage,
            'independent_driver',
          ]
        );
      } else if (eCreated.code === '42703' && emsg.includes('luggage_allowance_per_passenger')) {
        try {
          result = await runInsert(
            `INSERT INTO trips (
              driver_id, from_location, to_location, departure_time, arrival_time,
              fare_per_seat, total_capacity, available_seats,
              vehicle_number, vehicle_model_id, stops, status, require_approval, route_id, created_source
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
            RETURNING *`,
            [
              driverId, from_location, to_location, departureStr, arrivalStr,
              fare_per_seat, totalSeats, bookableSeats,
              vehicleNumber, vehicleModelId, stopsJson, 'scheduled', useRequireApproval, routeId,
              'independent_driver',
            ]
          );
        } catch (e2) {
          if (e2.code === '42703' && (e2.message || '').includes('created_source')) {
            result = await runInsert(
              `INSERT INTO trips (
                driver_id, from_location, to_location, departure_time, arrival_time,
                fare_per_seat, total_capacity, available_seats,
                vehicle_number, vehicle_model_id, stops, status, require_approval, route_id
              )
              VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
              RETURNING *`,
              [
                driverId, from_location, to_location, departureStr, arrivalStr,
                fare_per_seat, totalSeats, bookableSeats,
                vehicleNumber, vehicleModelId, stopsJson, 'scheduled', useRequireApproval, routeId,
              ]
            );
          } else {
            throw e2;
          }
        }
      } else if (eCreated.code === '42703' && emsg.includes('created_source')) {
        try {
          result = await runInsert(
            `INSERT INTO trips (
              driver_id, from_location, to_location, departure_time, arrival_time,
              fare_per_seat, total_capacity, available_seats,
              vehicle_number, vehicle_model_id, stops, status, require_approval, route_id,
              luggage_allowance_per_passenger
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
            RETURNING *`,
            [
              driverId, from_location, to_location, departureStr, arrivalStr,
              fare_per_seat, totalSeats, bookableSeats,
              vehicleNumber, vehicleModelId, stopsJson, 'scheduled', useRequireApproval, routeId,
              tripLuggage,
            ]
          );
        } catch (e3) {
          if (e3.code === '42703' && (e3.message || '').includes('luggage_allowance_per_passenger')) {
            result = await runInsert(
              `INSERT INTO trips (
                driver_id, from_location, to_location, departure_time, arrival_time,
                fare_per_seat, total_capacity, available_seats,
                vehicle_number, vehicle_model_id, stops, status, require_approval, route_id
              )
              VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
              RETURNING *`,
              [
                driverId, from_location, to_location, departureStr, arrivalStr,
                fare_per_seat, totalSeats, bookableSeats,
                vehicleNumber, vehicleModelId, stopsJson, 'scheduled', useRequireApproval, routeId,
              ]
            );
          } else {
            throw e3;
          }
        }
      } else {
        throw eCreated;
      }
    }
  } catch (err) {
    if (err.code === '42703' || (err.message && (err.message.includes('require_approval') || err.message.includes('vehicle_model_id')))) {
      try {
        result = await runInsert(
          `INSERT INTO trips (
            driver_id, from_location, to_location, departure_time, arrival_time,
            fare_per_seat, total_capacity, available_seats,
            vehicle_number, stops, status, route_id
          )
          VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
          RETURNING *`,
          [
            driverId, from_location, to_location, departureStr, arrivalStr,
            fare_per_seat, totalSeats, bookableSeats,
            vehicleNumber, stopsJson, 'scheduled', routeId
          ]
        );
      } catch (err2) {
        logger.error('Create trip INSERT fallback failed', { code: err2.code, message: err2.message });
        if (err2.code === '23502' && /vehicle_id|route_id/.test((err2.message || ''))) {
          throw ApiError.serviceUnavailable(
            'Rides could not be saved: database schema is outdated. On the server run: cd backend && npm run migrate && pm2 restart luharide-api'
          );
        }
        throw ApiError.serviceUnavailable('Database schema may be outdated. Run migrations (npm run migrate).');
      }
    } else if (err.code === '42P01') {
      logger.error('Create trip: trips table missing', { message: err.message });
      throw ApiError.serviceUnavailable('Trips table not available. Run database migrations.');
    } else if (err.code === '23502') {
      const msg = (err.message || '').toString();
      if (/vehicle_id|route_id/.test(msg)) {
        throw ApiError.serviceUnavailable(
          'Rides could not be saved: database schema is outdated. On the server run: cd backend && npm run migrate && pm2 restart luharide-api'
        );
      }
      throw ApiError.badRequest('Missing required trip data. Check from_location, to_location, and other fields.');
    } else if (err.code === '23514') {
      throw ApiError.badRequest('From and to locations are required for creating a trip.');
    } else {
      logger.error('Create trip INSERT failed', { code: err.code, message: err.message });
      throw err;
    }
  }

  const trip = result.rows[0];
  logger.info(`Trip created: id=${trip.id} driver=${driverId} from=${trip.from_location} to=${trip.to_location} departure=${trip.departure_time} (verify in DB with this id)`);

  ApiResponse.created(
    { trip },
    'Trip created successfully'
  ).send(res);
});

// ── Get trip details ────────────────────────────────────────────────────────
const getTripDetails = asyncHandler(async (req, res) => {
  const { id } = req.params;
  requireUuid(id);

  let result;
  try {
    result = await pool.query(
      `SELECT
        t.*,
        u.name as driver_name,
        u.email as driver_email,
        u.phone as driver_phone,
        u.whatsapp_number as driver_whatsapp,
        u.driver_verification_status as driver_verified,
        u.bio as driver_bio,
        u.luggage_allowance_per_passenger as driver_luggage_allowance
      FROM trips t
      LEFT JOIN users u ON t.driver_id = u.id
      WHERE t.id = $1`,
      [id]
    );
  } catch (err) {
    if (err.code === '42703') {
      result = await pool.query(
        `SELECT t.*, u.name as driver_name, u.email as driver_email, u.phone as driver_phone
         FROM trips t LEFT JOIN users u ON t.driver_id = u.id WHERE t.id = $1`,
        [id]
      );
    } else {
      throw err;
    }
  }

  if (result.rows.length === 0) {
    throw ApiError.notFound('Trip not found');
  }

  const trip = result.rows[0];

  const isDriver = req.user && req.user.id === trip.driver_id;
  const passengerId = req.user && !isDriver ? req.user.id : null;

  const bookingsResult = await pool.query(
    `SELECT seat_numbers, status, passenger_id FROM bookings
     WHERE trip_id = $1
       AND (
         status IN ('confirmed', 'pending')
         OR ($2::uuid IS NOT NULL AND passenger_id = $2::uuid)
       )`,
    [id, passengerId]
  );

  const booked = [];
  const pending = [];
  let userBookingStatus = null;
  for (const row of bookingsResult.rows) {
    if (passengerId && row.passenger_id === passengerId) {
      userBookingStatus = row.status;
    }
    if (row.status !== 'confirmed' && row.status !== 'pending') continue;
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
  bookedSet.add(1);
  const pendingSet = new Set(pending);
  const allTakenSet = new Set([...bookedSet, ...pendingSet]);
  const totalSeats = trip.total_seats ?? trip.total_capacity ?? 0;
  const availableSeats = Math.max(0, totalSeats - allTakenSet.size);

  const contactVisible = isDriver || userBookingStatus === 'confirmed' || userBookingStatus === 'completed';

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
        total_seats: totalSeats,
        vehicle_number: trip.vehicle_number,
        vehicle_model_id: trip.vehicle_model_id ?? null,
        stops: trip.stops,
        status: trip.status,
        driver: {
          id: trip.driver_id,
          name: trip.driver_name,
          email: trip.driver_email,
          phone: contactVisible ? (trip.driver_phone ?? null) : null,
          whatsapp_number: contactVisible ? (trip.driver_whatsapp ?? null) : null,
          isVerified: trip.driver_verified === 'approved',
          bio: trip.driver_bio ?? null,
          luggage_allowance_per_passenger: trip.luggage_allowance_per_passenger ?? null
        }
      },
      booked_seats: [...bookedSet].sort((a, b) => a - b),
      pending_seats: [...pendingSet].sort((a, b) => a - b),
      user_booking_status: userBookingStatus,
    },
    'Trip details'
  ).send(res);
});

// ── Get my trips (Driver only) ──────────────────────────────────────────────
const getMyTrips = asyncHandler(async (req, res) => {
  const driverId = req.user.id;
  const { status } = req.query;
  const days  = Math.min(60, Math.max(0, parseInt(req.query.days,  10) || 30));
  const page  = Math.max(1,  parseInt(req.query.page,  10) || 1);
  const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 20));
  const offset = (page - 1) * limit;

  const params = [driverId];
  let whereClauses = 'WHERE t.driver_id = $1';

  if (days > 0) {
    params.push(days);
    whereClauses += `
      AND (t.status = 'scheduled'
           OR t.departure_time >= NOW() - make_interval(days => $${params.length}))`;
  }

  if (status) {
    params.push(status);
    whereClauses += ` AND t.status = $${params.length}`;
  }

  params.push(limit, offset);

  const result = await pool.query(
    `SELECT t.*, COALESCE(b.pending_count, 0) AS pending_requests_count
     FROM trips t
     LEFT JOIN (
       SELECT trip_id, COUNT(*)::int AS pending_count
       FROM bookings WHERE status = 'pending'
       GROUP BY trip_id
     ) b ON b.trip_id = t.id
     ${whereClauses}
     ORDER BY pending_requests_count DESC, t.departure_time DESC
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );

  const trips = result.rows.map(row => ({
    ...row,
    pending_requests_count: parseInt(row.pending_requests_count, 10) || 0,
  }));

  ApiResponse.success(
    { trips, count: trips.length, page, limit, days_filter: days },
    'Trips retrieved'
  ).send(res);
});

// ── Get trip bookings (Driver only) ─────────────────────────────────────────
const getTripBookings = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;

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
      u.phone as passenger_phone,
      u.whatsapp_number as passenger_whatsapp
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
      phone: row.passenger_phone,
      whatsapp_number: row.passenger_whatsapp
    }
  }));

  ApiResponse.success(
    { bookings },
    'Bookings retrieved'
  ).send(res);
});

// ── Exports (barrel) ────────────────────────────────────────────────────────
module.exports = {
  createTrip,
  searchTrips,
  getTripDetails,
  getMyTrips,
  getLocationSuggestions,
  getTripBookings,
  getTripBookedSeats,
  getRecentRoutes,
  saveRecentRoute,
  startTrip,
  completeTrip,
  cancelTrip,
  deleteTrip
};
