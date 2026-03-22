const { pool, queryRead } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { emitNotificationToUser, emitTripUpdated } = require('../socket/realtimeEmitter');

/**
 * Create a new trip (Driver only)
 * POST /api/trips
 */
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
  } = req.body;

  const driverId = req.user.id;

  // Sanitize: trim, limit length, ensure non-empty so DB never gets invalid data
  const from_location = (rawFrom != null ? String(rawFrom).trim() : '').slice(0, 200);
  const to_location = (rawTo != null ? String(rawTo).trim() : '').slice(0, 200);
  if (!from_location || from_location.length < 2) {
    throw ApiError.badRequest('From location is required (at least 2 characters).');
  }
  if (!to_location || to_location.length < 2) {
    throw ApiError.badRequest('To location is required (at least 2 characters).');
  }
  const fare_per_seat = Number(rawFare);
  if (Number.isNaN(fare_per_seat) || fare_per_seat <= 0) {
    throw ApiError.badRequest('Fare per seat must be a positive number.');
  }

  // Optional canonical route binding (UUID as text). Used for consistent search by route_id.
  const routeId = rawRouteId != null ? String(rawRouteId).trim() : null;

  // MUST use verified vehicle - no manual override. Driver must complete verification first.
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

  const MAX_SEATS = 32; // Independent driver: max seat count for layout and booking
  const cap = verif.rows[0].vehicle_capacity;
  let totalSeats = (cap != null && cap > 0) ? cap : 7;
  if (totalSeats > MAX_SEATS) totalSeats = MAX_SEATS;
  if (totalSeats < 1) totalSeats = 1;
  const vehicleNumber = (verif.rows[0].vehicle_registration || bodyVehicleNumber || '').toString().trim().slice(0, 20);
  let vehicleModelId = null;
  try {
    const verif2 = await pool.query(
      `SELECT vehicle_model_id FROM driver_verification_requests WHERE user_id = $1 AND status = 'approved' ORDER BY updated_at DESC LIMIT 1`,
      [driverId]
    );
    if (verif2.rows[0] && verif2.rows[0].vehicle_model_id) vehicleModelId = verif2.rows[0].vehicle_model_id;
  } catch (_) {
    // Column may not exist; ignore
  }

  // Parse as UTC (mobile sends ISO with Z). Store as literal YYYY-MM-DD HH:mm:ss so DB keeps same numbers in UTC.
  const departureDate = new Date(departure_time);
  if (Number.isNaN(departureDate.getTime())) {
    throw ApiError.badRequest('Invalid departure_time. Use ISO 8601 format (e.g. with Z for UTC).');
  }
  const arrivalDate = new Date(departureDate.getTime() + 2 * 60 * 60 * 1000);
  const departureStr = departureDate.toISOString().slice(0, 19).replace('T', ' ');
  const arrivalStr = arrivalDate.toISOString().slice(0, 19).replace('T', ' ');

  const useRequireApproval = require_approval === false ? false : true;
  const stopsArray = Array.isArray(stops) ? stops : [];
  const stopsJson = JSON.stringify(stopsArray.map(s => (s != null ? String(s).trim() : '').slice(0, 200)));

  let result;
  const runInsert = (query, params) => pool.query(query, params);

  // DB schema: trips may have vehicle_id/route_id NOT NULL until migration 003 or 017 is run.
  try {
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
          fare_per_seat, totalSeats, totalSeats,
          vehicleNumber, vehicleModelId, stopsJson, 'scheduled', useRequireApproval, routeId,
          'independent_driver',
        ]
      );
    } catch (eCreated) {
      if (eCreated.code === '42703' && (eCreated.message || '').includes('created_source')) {
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
            fare_per_seat, totalSeats, totalSeats,
            vehicleNumber, vehicleModelId, stopsJson, 'scheduled', useRequireApproval, routeId,
          ]
        );
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
            fare_per_seat, totalSeats, totalSeats,
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
    `Trip created successfully. ID: ${trip.id}`
  ).send(res);
});

/**
 * Search trips
 * GET /api/trips/search?from=Dehradun&to=Purola&date=2026-02-23
 * or GET /api/trips/search?route_id=uuid&date=2026-02-23 (canonical route-based search)
 * Params from query (GET) or body (POST). Aliases: from_location→from, to_location→to.
 */
const searchTrips = asyncHandler(async (req, res) => {
  const q = { ...req.query, ...(req.body && typeof req.body === 'object' ? req.body : {}) };
  const from = (q.from != null ? String(q.from) : q.from_location != null ? String(q.from_location) : '').trim();
  const to = (q.to != null ? String(q.to) : q.to_location != null ? String(q.to_location) : '').trim();
  const date = (q.date != null ? String(q.date) : '').trim();
  const routeId = q.route_id != null ? String(q.route_id).trim() : '';

  if ((!routeId && (!from || !to)) || !date) {
    throw ApiError.badRequest(
      routeId
        ? 'date is required. Example: GET /api/trips/search?route_id=uuid&date=2026-02-23'
        : 'from, to, and date are required. Example: GET /api/trips/search?from=Dehradun&to=Purola&date=2026-02-23'
    );
  }

  const dateStr = date.slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
    throw ApiError.badRequest('Invalid date. Use YYYY-MM-DD (e.g. 2026-02-23).');
  }

  // KVM / small VPS: cap page size and offset so one search cannot scan huge result sets
  const DEFAULT_SEARCH_LIMIT = 40;
  const MAX_SEARCH_LIMIT = 80;
  const MAX_SEARCH_OFFSET = 400;
  const rawLimit = parseInt(q.limit, 10);
  const rawOffset = parseInt(q.offset, 10);
  const limit = Math.min(MAX_SEARCH_LIMIT, Math.max(1, Number.isFinite(rawLimit) ? rawLimit : DEFAULT_SEARCH_LIMIT));
  const offset = Math.min(MAX_SEARCH_OFFSET, Math.max(0, Number.isFinite(rawOffset) ? rawOffset : 0));

  // Normalize: lowercase; strip spaces, commas, dots, dashes, slashes so search matches more typos
  const normLoc = (s) => s.toLowerCase().replace(/[\s,.\-_:;/\\]+/g, '');
  const fromNorm = normLoc(from);
  const toNorm   = normLoc(to);
  const fromPat  = `%${fromNorm}%`;
  const toPat    = `%${toNorm}%`;

  // Run trips and union queries in parallel — faster search, no speed compromise.
  const runTripsQuery = async () => {
    if (routeId) {
      return queryRead(
        `SELECT t.*, u.name as driver_name, u.email as driver_email, u.phone as driver_phone,
                u.whatsapp_number as driver_whatsapp, u.driver_verification_status as driver_verified,
                u.bio as driver_bio, u.luggage_allowance_per_passenger as driver_luggage_allowance
         FROM trips t
         LEFT JOIN users u ON t.driver_id = u.id
         WHERE t.route_id = $1
           AND (t.departure_time AT TIME ZONE 'UTC') >= (($2::text || ' 00:00:00')::timestamp AT TIME ZONE 'UTC')
           AND (t.departure_time AT TIME ZONE 'UTC') < (($2::text || ' 00:00:00')::timestamp AT TIME ZONE 'UTC' + interval '1 day')
           AND t.status = 'scheduled'
           AND COALESCE(t.available_seats, t.total_capacity, 0) > 0
         ORDER BY t.departure_time ASC
         OFFSET $3 LIMIT $4`,
        [routeId, dateStr, offset, limit]
      );
    } else {
      try {
        return queryRead(
          `SELECT t.*, u.name as driver_name, u.email as driver_email, u.phone as driver_phone,
                  u.whatsapp_number as driver_whatsapp, u.driver_verification_status as driver_verified,
                  u.bio as driver_bio, u.luggage_allowance_per_passenger as driver_luggage_allowance
           FROM trips t
           LEFT JOIN users u ON t.driver_id = u.id
           WHERE t.from_location_norm LIKE $1
             AND t.to_location_norm   LIKE $2
             AND t.departure_time >= ($3::date)::timestamp
             AND t.departure_time <  ($3::date)::timestamp + interval '1 day'
             AND t.status = 'scheduled'
             AND COALESCE(t.available_seats, t.total_capacity, 0) > 0
           ORDER BY t.departure_time ASC
           OFFSET $4 LIMIT $5`,
          [fromPat, toPat, dateStr, offset, limit]
        );
      } catch (colErr) {
        if (colErr.code === '42703') {
          return queryRead(
            `SELECT t.*, u.name as driver_name, u.email as driver_email, u.phone as driver_phone,
                    u.whatsapp_number as driver_whatsapp, u.driver_verification_status as driver_verified,
                    u.bio as driver_bio, u.luggage_allowance_per_passenger as driver_luggage_allowance
             FROM trips t
             LEFT JOIN users u ON t.driver_id = u.id
             WHERE COALESCE(TRIM(t.from_location), '') <> ''
               AND COALESCE(TRIM(t.to_location), '') <> ''
               AND regexp_replace(LOWER(TRIM(t.from_location)), '\s+', '', 'g') LIKE $1
               AND regexp_replace(LOWER(TRIM(t.to_location)),   '\s+', '', 'g') LIKE $2
               AND (t.departure_time AT TIME ZONE 'UTC') >= (($3::text || ' 00:00:00')::timestamp AT TIME ZONE 'UTC')
               AND (t.departure_time AT TIME ZONE 'UTC') <  (($3::text || ' 00:00:00')::timestamp AT TIME ZONE 'UTC' + interval '1 day')
             AND t.status = 'scheduled'
             AND COALESCE(t.available_seats, t.total_capacity, 0) > 0
             ORDER BY t.departure_time ASC OFFSET $4 LIMIT $5`,
            [fromPat, toPat, dateStr, offset, limit]
          );
        }
        throw colErr;
      }
    }
  };

  const runUnionQuery = async () => {
    try {
      return queryRead(
        `SELECT s.id, s.from_location, s.to_location, s.departure_time, s.status,
                d.name AS driver_name, d.vehicle_number, d.phone, d.whatsapp_number, u.name AS union_name
         FROM union_schedules s
         JOIN union_drivers d ON d.id = s.union_driver_id
         JOIN unions u ON u.id = s.union_id
         WHERE s.status = 'scheduled'
           AND s.from_location_norm LIKE $1 AND s.to_location_norm LIKE $2
           AND s.departure_time >= ($3::date)::timestamp
           AND s.departure_time <  ($3::date)::timestamp + interval '1 day'
         ORDER BY s.departure_time ASC OFFSET $4 LIMIT $5`,
        [fromPat, toPat, dateStr, offset, limit]
      );
    } catch (err) {
      if (err.code === '42P01') return { rows: [] };
      if (err.code === '42703') {
        try {
          return queryRead(
            `SELECT s.id, s.from_location, s.to_location, s.departure_time, s.status,
                    d.name AS driver_name, d.vehicle_number, d.phone, d.whatsapp_number, u.name AS union_name
             FROM union_schedules s
             JOIN union_drivers d ON d.id = s.union_driver_id
             JOIN unions u ON u.id = s.union_id
             WHERE s.status = 'scheduled'
               AND COALESCE(TRIM(s.from_location), '') <> '' AND COALESCE(TRIM(s.to_location), '') <> ''
               AND regexp_replace(LOWER(TRIM(s.from_location)), '\s+', '', 'g') LIKE $1
               AND regexp_replace(LOWER(TRIM(s.to_location)),   '\s+', '', 'g') LIKE $2
               AND (s.departure_time AT TIME ZONE 'UTC') >= (($3::text || ' 00:00:00')::timestamp AT TIME ZONE 'UTC')
               AND (s.departure_time AT TIME ZONE 'UTC') <  (($3::text || ' 00:00:00')::timestamp AT TIME ZONE 'UTC' + interval '1 day')
             ORDER BY s.departure_time ASC OFFSET $4 LIMIT $5`,
            [fromPat, toPat, dateStr, offset, limit]
          );
        } catch (_) {
          return { rows: [] };
        }
      }
      throw err;
    }
  };

  const [result, unionResult] = await Promise.all([runTripsQuery(), runUnionQuery()]);

  const trips = result.rows.map(trip => ({
    id: trip.id,
    from_location: trip.from_location,
    to_location: trip.to_location,
    departure_time: trip.departure_time,
    arrival_time: trip.arrival_time,
    fare_per_seat: trip.fare_per_seat,
    available_seats: trip.available_seats ?? trip.total_capacity ?? 0,
    total_seats: trip.total_seats ?? trip.total_capacity ?? 0,
    vehicle_number: trip.vehicle_number,
    vehicle_model_id: trip.vehicle_model_id ?? null,
    stops: trip.stops,
    status: trip.status,
    driver: {
      id: trip.driver_id,
      name: trip.driver_name,
      email: trip.driver_email,
      phone: trip.driver_phone,
      whatsapp_number: trip.driver_whatsapp ?? null,
      isVerified: trip.driver_verified === 'approved',
      bio: trip.driver_bio ?? null,
      luggage_allowance_per_passenger: trip.driver_luggage_allowance ?? null
    }
  }));

  const unionRides = unionResult.rows.map(row => ({
    id: row.id,
    from_location: row.from_location,
    to_location: row.to_location,
    departure_time: row.departure_time,
    status: row.status,
    driver_name: row.driver_name,
    vehicle_number: row.vehicle_number,
    phone: row.phone,
    whatsapp_number: row.whatsapp_number,
    union_name: row.union_name,
  }));

  ApiResponse.success(
    {
      trips,
      count: trips.length,
      unionRides,
      union_count: unionRides.length,
      pagination: {
        limit,
        offset,
        max_limit: MAX_SEARCH_LIMIT,
        max_offset: MAX_SEARCH_OFFSET
      }
    },
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
    'SELECT id, total_capacity AS total_seats FROM trips WHERE id = $1 AND status = $2',
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
  bookedSet.add(1); // Seat 1 = driver (reserved, not bookable)
  const pendingSet = new Set(pending);
  const allTakenSet = new Set([...bookedSet, ...pending]);
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

const RECENT_ROUTES_LIMIT = 10;
const RECENT_ROUTES_MAX_PER_USER = 20;

/**
 * Get recent routes for quick search (authenticated)
 * GET /api/trips/recent-routes
 */
const getRecentRoutes = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const result = await pool.query(
    `SELECT id, from_location, to_location, created_at
     FROM recent_routes
     WHERE user_id = $1
     ORDER BY created_at DESC
     LIMIT $2`,
    [userId, RECENT_ROUTES_LIMIT]
  );
  ApiResponse.success(
    { routes: result.rows },
    'Recent routes'
  ).send(res);
});

/**
 * Save a route as recent (on search) – keeps last N per user
 * POST /api/trips/recent-routes
 * Body: { from_location, to_location }
 */
const saveRecentRoute = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const from_location = (req.body && req.body.from_location) ? String(req.body.from_location).trim().slice(0, 200) : null;
  const to_location = (req.body && req.body.to_location) ? String(req.body.to_location).trim().slice(0, 200) : null;
  if (!from_location || !to_location) {
    throw ApiError.badRequest('from_location and to_location are required');
  }
  await pool.query(
    `INSERT INTO recent_routes (user_id, from_location, to_location) VALUES ($1, $2, $3)`,
    [userId, from_location, to_location]
  );
  // Single atomic trim: keep only the most recent N rows per user using a window function.
  // More efficient than COUNT + NOT IN subquery.
  await pool.query(
    `DELETE FROM recent_routes
     WHERE user_id = $1
       AND id IN (
         SELECT id FROM (
           SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
           FROM recent_routes WHERE user_id = $1
         ) ranked
         WHERE rn > $2
       )`,
    [userId, RECENT_ROUTES_MAX_PER_USER]
  );
  ApiResponse.success({ saved: true }, 'Route saved').send(res);
});

/**
 * Get trip details (includes booked & pending seats for seat selection UI)
 * GET /api/trips/:id
 */
const getTripDetails = asyncHandler(async (req, res) => {
  const { id } = req.params;

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

  // Single query: seat occupancy + passenger booking row (one DB round-trip vs two)
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
  bookedSet.add(1); // Seat 1 = driver (reserved, not bookable)
  const pendingSet = new Set(pending);
  const allTakenSet = new Set([...bookedSet, ...pendingSet]);
  const totalSeats = trip.total_seats ?? trip.total_capacity ?? 0;
  const availableSeats = Math.max(0, totalSeats - allTakenSet.size);

  // Only reveal driver contact if the requesting user has a confirmed booking (or is the driver)
  const contactVisible = isDriver || userBookingStatus === 'confirmed';

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
          // Phone & WhatsApp only revealed after confirmed booking
          phone: contactVisible ? (trip.driver_phone ?? null) : null,
          whatsapp_number: contactVisible ? (trip.driver_whatsapp ?? null) : null,
          isVerified: trip.driver_verified === 'approved',
          bio: trip.driver_bio ?? null,
          luggage_allowance_per_passenger: trip.driver_luggage_allowance ?? null
        }
      },
      booked_seats: [...bookedSet].sort((a, b) => a - b),
      pending_seats: [...pendingSet].sort((a, b) => a - b),
      user_booking_status: userBookingStatus,
    },
    'Trip details'
  ).send(res);
});

/**
 * Get my trips (Driver only)
 * GET /api/trips/my-trips?status=scheduled&days=30&page=1&limit=20
 *
 * Params:
 *   status — filter by trip status (optional)
 *   days   — how many past days to include (default 30, 0 = all within retention)
 *   page   — page number (default 1)
 *   limit  — results per page (default 20, max 50)
 */
const getMyTrips = asyncHandler(async (req, res) => {
  const driverId = req.user.id;
  const { status } = req.query;
  const days  = Math.min(60, Math.max(0, parseInt(req.query.days,  10) || 30));
  const page  = Math.max(1,  parseInt(req.query.page,  10) || 1);
  const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 20));
  const offset = (page - 1) * limit;

  const params = [driverId];
  let whereClauses = 'WHERE t.driver_id = $1';

  // Scheduled trips always shown regardless of date — driver needs to action them
  // Completed/cancelled trips respect the days filter
  if (days > 0) {
    whereClauses += `
      AND (t.status = 'scheduled'
           OR t.departure_time >= NOW() - INTERVAL '${days} days')`;
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
 * Start trip (Driver only) - scheduled → in_progress
 * PUT /api/trips/:id/start
 */
const startTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  const driverId = req.user.id;

  const tripResult = await pool.query(
    'SELECT id, status FROM trips WHERE id = $1 AND driver_id = $2',
    [tripId, driverId]
  );

  if (tripResult.rows.length === 0) {
    throw ApiError.notFound('Trip not found');
  }

  const trip = tripResult.rows[0];
  if (trip.status !== 'scheduled') {
    throw ApiError.badRequest(`Cannot start trip. Current status: ${trip.status}. Only scheduled trips can be started.`);
  }

  try {
    await pool.query(
      `UPDATE trips SET status = 'in_progress', started_at = COALESCE(started_at, NOW()) WHERE id = $1`,
      [tripId]
    );
  } catch (err) {
    if (err.code === '42703') {
      await pool.query("UPDATE trips SET status = 'in_progress' WHERE id = $1", [tripId]);
    } else {
      throw err;
    }
  }

  ApiResponse.success(
    { status: 'in_progress' },
    'Ride started'
  ).send(res);
});

/**
 * Complete trip (Driver only) - in_progress → completed
 * PUT /api/trips/:id/complete
 */
const completeTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  const driverId = req.user.id;

  const tripResult = await pool.query(
    'SELECT id, status FROM trips WHERE id = $1 AND driver_id = $2',
    [tripId, driverId]
  );

  if (tripResult.rows.length === 0) {
    throw ApiError.notFound('Trip not found');
  }

  const trip = tripResult.rows[0];
  if (trip.status !== 'in_progress') {
    throw ApiError.badRequest(`Cannot complete trip. Current status: ${trip.status}. Only in-progress trips can be completed.`);
  }

  await pool.query(
    "UPDATE trips SET status = 'completed' WHERE id = $1",
    [tripId]
  );

  ApiResponse.success(
    { status: 'completed' },
    'Ride completed'
  ).send(res);
});

/** BlaBlaCar-style: driver cannot cancel trip when confirmed passengers exist and departure is within this many hours */
const DRIVER_CANCEL_CUTOFF_HOURS = 2;

/**
 * Cancel trip (Driver only) - BlaBlaCar style
 * Driver can cancel only if: no confirmed bookings, OR departure is more than DRIVER_CANCEL_CUTOFF_HOURS away.
 * Within cutoff with confirmed passengers → reject (protects passengers).
 * PUT /api/trips/:id/cancel
 */
const cancelTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  const driverId = req.user.id;

  const tripResult = await pool.query(
    'SELECT id, status, departure_time, driver_id FROM trips WHERE id = $1 AND driver_id = $2',
    [tripId, driverId]
  );

  if (tripResult.rows.length === 0) {
    throw ApiError.notFound('Trip not found');
  }

  const trip = tripResult.rows[0];
  if (trip.status === 'cancelled' || trip.status === 'completed') {
    throw ApiError.badRequest(`Trip is already ${trip.status}. Cannot cancel.`);
  }
  // After ride start: driver cancel disabled (both sides rule)
  if (trip.status === 'in_progress') {
    throw ApiError.badRequest('Ride has already started. Cancellation not allowed.');
  }

  const departureTimeMs = new Date(trip.departure_time).getTime();
  const now = Date.now();
  if (now >= departureTimeMs) {
    throw ApiError.badRequest('Ride start time has passed. Cancellation not allowed.');
  }

  const confirmedBookings = await pool.query(
    `SELECT id, passenger_id, seat_numbers FROM bookings WHERE trip_id = $1 AND status = 'confirmed'`,
    [tripId]
  );

  const cutoffMs = DRIVER_CANCEL_CUTOFF_HOURS * 60 * 60 * 1000;
  if (confirmedBookings.rows.length > 0 && (departureTimeMs - now) < cutoffMs) {
    throw ApiError.badRequest(
      `Cannot cancel trip. You have ${confirmedBookings.rows.length} confirmed passenger(s). ` +
      `Driver cannot cancel within ${DRIVER_CANCEL_CUTOFF_HOURS} hours of departure (BlaBlaCar-style).`
    );
  }

  await pool.query(
    `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(), cancellation_reason = 'Driver cancelled the trip' WHERE trip_id = $1 AND status IN ('pending', 'confirmed')`,
    [tripId]
  );

  let seatsToRelease = 0;
  for (const row of confirmedBookings.rows) {
    const seats = Array.isArray(row.seat_numbers) ? row.seat_numbers : [];
    seatsToRelease += seats.length;
  }
  if (seatsToRelease > 0) {
    await pool.query(
      'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
      [seatsToRelease, tripId]
    );
  }

  await pool.query(
    "UPDATE trips SET status = 'cancelled' WHERE id = $1",
    [tripId]
  );

  if (confirmedBookings.rows.length > 0) {
    const placeholders = confirmedBookings.rows
      .map((_, i) => `($${i + 1}, 'trip_cancelled', 'Ride cancelled', 'The driver cancelled this ride. You are not charged.')`)
      .join(', ');
    const flatParams = confirmedBookings.rows.map(r => r.passenger_id);
    try {
      const nIns = await pool.query(
        `INSERT INTO notifications (user_id, type, title, body) VALUES ${placeholders}
         RETURNING id, user_id, type, title, body, created_at, is_read`,
        flatParams
      );
      for (const row of nIns.rows) {
        emitNotificationToUser(row.user_id, row);
      }
    } catch (e) {
      logger.warn('Batch passenger cancel notification failed:', e.message);
    }
  }

  emitTripUpdated(tripId, { reason: 'driver_cancelled_trip' });

  logger.info(`Trip cancelled: ${tripId} by driver ${driverId}`);

  ApiResponse.success(
    { status: 'cancelled' },
    'Trip cancelled. Passengers have been notified.'
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
  getRecentRoutes,
  saveRecentRoute,
  startTrip,
  completeTrip,
  cancelTrip,
  deleteTrip
};
