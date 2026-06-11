const { pool, queryRead } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { emitNotificationToUser, emitTripUpdated } = require('../socket/realtimeEmitter');
const retentionConfig = require('../config/retentionConfig');
const toTitleCase = require('../utils/titleCase');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function requireUuid(id) {
  if (!id || !UUID_RE.test(id)) throw ApiError.badRequest('Invalid trip ID');
}

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
    luggage_allowance_per_passenger: rawTripLuggage,
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
        'Aapne recently bahut baar ride cancel ki hai. Kuch samay baad try karein.'
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

  // Sanitize: trim, limit length, ensure non-empty so DB never gets invalid data
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
  if (departureDate.getTime() < Date.now()) {
    throw ApiError.badRequest('Departure time cannot be in the past');
  }
  const MIN_ADVANCE_HOURS = 2;
  const minAdvanceMs = MIN_ADVANCE_HOURS * 60 * 60 * 1000;
  if (departureDate.getTime() - Date.now() < minAdvanceMs) {
    throw ApiError.badRequest(
      `Ride departure must be at least ${MIN_ADVANCE_HOURS} hours from now.`
    );
  }
  const arrivalDate = new Date(departureDate.getTime() + 2 * 60 * 60 * 1000);

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
      'Aapki ek aur ride iss time pe already scheduled hai. Pehle woh complete ya cancel karein.'
    );
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

  // DB schema: trips may have vehicle_id/route_id NOT NULL until migration 003 or 017 is run.
  try {
    try {
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
          fare_per_seat, totalSeats, totalSeats,
          vehicleNumber, vehicleModelId, stopsJson, 'scheduled', useRequireApproval, routeId,
          tripLuggage,
          'independent_driver',
        ]
      );
    } catch (eCreated) {
      const emsg = (eCreated.message || '').toString();
      if (eCreated.code === '42703' && emsg.includes('luggage_allowance_per_passenger')) {
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
                fare_per_seat, totalSeats, totalSeats,
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
              fare_per_seat, totalSeats, totalSeats,
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
                fare_per_seat, totalSeats, totalSeats,
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

// Explicit columns for search — avoids SELECT t.* bandwidth/memory waste at 1M+ rows
const _TRIP_COLS = `t.id, t.from_location, t.to_location, t.departure_time, t.arrival_time,
  t.fare_per_seat, t.available_seats, t.total_capacity, t.vehicle_number,
  t.vehicle_model_id, t.stops, t.status, t.driver_id, t.luggage_allowance_per_passenger`;
const _DRIVER_COLS = `u.name AS driver_name, u.email AS driver_email, u.phone AS driver_phone,
  u.whatsapp_number AS driver_whatsapp, u.driver_verification_status AS driver_verified,
  u.bio AS driver_bio`;

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

  // Each trip/schedule row: still list only if (that row's departure + grace) is in the future.
  // graceMin: show trips up to N minutes past departure (0 = only future trips)
  // Keep departure_time bare (no AT TIME ZONE wrap) so B-tree index can be used
  const graceMin = retentionConfig.tripSearchGraceMinutesAfterDeparture;
  const depStillVisible = `t.departure_time > (NOW() AT TIME ZONE 'UTC') - (${graceMin} * INTERVAL '1 minute')`;
  const unionDepStillVisible = `s.departure_time > (NOW() AT TIME ZONE 'UTC') - (${graceMin} * INTERVAL '1 minute')`;

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
        `SELECT ${_TRIP_COLS}, ${_DRIVER_COLS}
         FROM trips t
         LEFT JOIN users u ON t.driver_id = u.id
         WHERE t.route_id = $1
           AND t.departure_time >= ($2::date)::timestamp
           AND t.departure_time <  ($2::date)::timestamp + interval '1 day'
           AND t.status = 'scheduled'
           AND COALESCE(t.available_seats, t.total_capacity, 0) > 0
           AND ${depStillVisible}
         ORDER BY t.departure_time ASC
         OFFSET $3 LIMIT $4`,
        [routeId, dateStr, offset, limit]
      );
    } else {
      try {
        return queryRead(
          `SELECT ${_TRIP_COLS}, ${_DRIVER_COLS}
           FROM trips t
           LEFT JOIN users u ON t.driver_id = u.id
           WHERE t.from_location_norm LIKE $1
             AND t.to_location_norm   LIKE $2
             AND t.departure_time >= ($3::date)::timestamp
             AND t.departure_time <  ($3::date)::timestamp + interval '1 day'
             AND t.status = 'scheduled'
             AND COALESCE(t.available_seats, t.total_capacity, 0) > 0
             AND ${depStillVisible}
           ORDER BY t.departure_time ASC
           OFFSET $4 LIMIT $5`,
          [fromPat, toPat, dateStr, offset, limit]
        );
      } catch (colErr) {
        if (colErr.code === '42703') {
          return queryRead(
            `SELECT ${_TRIP_COLS}, ${_DRIVER_COLS}
             FROM trips t
             LEFT JOIN users u ON t.driver_id = u.id
             WHERE COALESCE(TRIM(t.from_location), '') <> ''
               AND COALESCE(TRIM(t.to_location), '') <> ''
               AND regexp_replace(LOWER(TRIM(t.from_location)), '\s+', '', 'g') LIKE $1
               AND regexp_replace(LOWER(TRIM(t.to_location)),   '\s+', '', 'g') LIKE $2
               AND t.departure_time >= ($3::date)::timestamp
               AND t.departure_time <  ($3::date)::timestamp + interval '1 day'
             AND t.status = 'scheduled'
             AND COALESCE(t.available_seats, t.total_capacity, 0) > 0
             AND ${depStillVisible}
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
                d.name AS driver_name, d.vehicle_number, d.phone, d.whatsapp_number, u.name AS union_name,
                s.union_driver_id, s.union_id
         FROM union_schedules s
         JOIN union_drivers d ON d.id = s.union_driver_id
         JOIN unions u ON u.id = s.union_id
         WHERE s.status = 'scheduled'
           AND s.from_location_norm LIKE $1 AND s.to_location_norm LIKE $2
           AND s.departure_time >= ($3::date)::timestamp
           AND s.departure_time <  ($3::date)::timestamp + interval '1 day'
           AND ${unionDepStillVisible}
         ORDER BY s.departure_time ASC OFFSET $4 LIMIT $5`,
        [fromPat, toPat, dateStr, offset, limit]
      );
    } catch (err) {
      if (err.code === '42P01') return { rows: [] };
      if (err.code === '42703') {
        try {
          return queryRead(
            `SELECT s.id, s.from_location, s.to_location, s.departure_time, s.status,
                    d.name AS driver_name, d.vehicle_number, d.phone, d.whatsapp_number, u.name AS union_name,
                    s.union_driver_id, s.union_id
             FROM union_schedules s
             JOIN union_drivers d ON d.id = s.union_driver_id
             JOIN unions u ON u.id = s.union_id
             WHERE s.status = 'scheduled'
               AND COALESCE(TRIM(s.from_location), '') <> '' AND COALESCE(TRIM(s.to_location), '') <> ''
               AND regexp_replace(LOWER(TRIM(s.from_location)), '\s+', '', 'g') LIKE $1
               AND regexp_replace(LOWER(TRIM(s.to_location)),   '\s+', '', 'g') LIKE $2
               AND s.departure_time >= ($3::date)::timestamp
               AND s.departure_time <  ($3::date)::timestamp + interval '1 day'
               AND ${unionDepStillVisible}
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

  // allSettled: one query failure returns partial results instead of killing both
  const [_tripsSettled, _unionSettled] = await Promise.allSettled([runTripsQuery(), runUnionQuery()]);
  if (_tripsSettled.status === 'rejected' && _unionSettled.status === 'rejected') {
    throw _tripsSettled.reason;
  }
  if (_tripsSettled.status === 'rejected') {
    logger.warn('Search: trips query failed, returning union only:', _tripsSettled.reason?.message);
  }
  if (_unionSettled.status === 'rejected') {
    logger.warn('Search: union query failed, returning trips only:', _unionSettled.reason?.message);
  }
  const result = _tripsSettled.status === 'fulfilled' ? _tripsSettled.value : { rows: [] };
  const unionResult = _unionSettled.status === 'fulfilled' ? _unionSettled.value : { rows: [] };

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
      phone: trip.driver_phone ?? null,
      whatsapp_number: trip.driver_whatsapp ?? null,
      isVerified: trip.driver_verified === 'approved',
      bio: trip.driver_bio ?? null,
      luggage_allowance_per_passenger: trip.luggage_allowance_per_passenger ?? null
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
    union_driver_id: row.union_driver_id,
    union_id: row.union_id,
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
  requireUuid(tripId);

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
  const from_location = (req.body && req.body.from_location) ? toTitleCase(String(req.body.from_location).trim().slice(0, 200)) : null;
  const to_location = (req.body && req.body.to_location) ? toTitleCase(String(req.body.to_location).trim().slice(0, 200)) : null;
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

/**
 * Get location suggestions
 * GET /api/trips/locations?q=Deh
 */
const UTTARAKHAND_LOCATIONS = [
  // District HQs
  'Dehradun', 'Haridwar', 'Rishikesh', 'Mussoorie', 'Nainital', 'Almora',
  'Haldwani', 'Roorkee', 'Rudrapur', 'Kashipur', 'Pithoragarh', 'Chamoli',
  'Uttarkashi', 'Tehri Garhwal', 'Tehri', 'Pauri Garhwal', 'Pauri',
  'Bageshwar', 'Champawat', 'Udham Singh Nagar',
  // Major towns & CDBlocks
  'Purola', 'Mori', 'Barkot', 'Naugaon', 'Dunda', 'Chinyalisaur',
  'Rajgarhi', 'Jaunpur', 'Tyuni',
  'Chakrata', 'Kalsi', 'Vikasnagar', 'Sahaspur', 'Raipur', 'Doiwala',
  'Herbertpur', 'Laksar', 'Bhagwanpur', 'Narsan', 'Bahadrabad',
  'Roorkee', 'Jhabrera', 'Landhaura',
  'Kotdwar', 'Lansdowne', 'Dugadda', 'Yamkeshwar', 'Pokhra', 'Bironkhal',
  'Ekeshwar', 'Rikhnikhal', 'Satpuli',
  'Devprayag', 'Narendranagar', 'Pratapnagar', 'Jakhnidhar', 'Ghansali',
  'Chamba', 'Dhanaulti', 'New Tehri',
  'Joshimath', 'Gopeshwar', 'Karnaprayag', 'Tharali', 'Gairsain',
  'Dewal', 'Narayanbagar', 'Pokhari',
  'Rudraprayag', 'Ukhimath', 'Augustmuni', 'Jakholi',
  'Srinagar Garhwal', 'Srinagar',
  'Kedarnath', 'Badrinath', 'Gangotri', 'Yamunotri',
  'Auli', 'Chopta', 'Tungnath', 'Hemkund Sahib',
  'Ranikhet', 'Dwarahat', 'Bhikiyasain', 'Chaukhutia', 'Someshwar',
  'Hawalbagh', 'Takula', 'Lamgara', 'Sult', 'Dhari',
  'Bhowali', 'Bhimtal', 'Ramgarh', 'Mukteshwar', 'Betalghat', 'Okhalkanda',
  'Haldwani', 'Lalkuan', 'Ramnagar', 'Dhari',
  'Khatima', 'Sitarganj', 'Bazpur', 'Gadarpur', 'Jaspur',
  'Tanakpur', 'Banbasa', 'Lohaghat', 'Pati', 'Barakot',
  'Berinag', 'Gangolihat', 'Dharchula', 'Munsiyari', 'Kapkot',
  'Kanda', 'Garur',
  'Haridwar', 'Manglaur', 'Piran Kaliyar',
  'Kathgodam', 'Pantnagar', 'Kichha', 'Kelakhera',
  'Rishikesh', 'Muni Ki Reti', 'Tapovan',
  'Dehradun Clock Tower', 'Rajpur Road', 'ISBT Dehradun',
  'Jolly Grant Airport', 'Pantnagar Airport',
];

const getLocationSuggestions = asyncHandler(async (req, res) => {
  const { q } = req.query;

  if (!q || q.length < 2) {
    return ApiResponse.success({ suggestions: [] }, 'No suggestions').send(res);
  }

  const qLower = q.toLowerCase().trim();
  const qNorm = qLower.replace(/[\s,.\-_:;/\\]+/g, '');
  const normPat = `%${qNorm}%`;

  let result;
  try {
    result = await queryRead(
      `SELECT DISTINCT location FROM (
         SELECT from_location AS location FROM trips WHERE from_location_norm LIKE $1
         UNION
         SELECT to_location AS location FROM trips WHERE to_location_norm LIKE $1
         UNION
         SELECT from_location AS location FROM union_schedules WHERE from_location_norm LIKE $1
         UNION
         SELECT to_location AS location FROM union_schedules WHERE to_location_norm LIKE $1
       ) AS locations
       LIMIT 30`,
      [normPat]
    );
  } catch (err) {
    if (err.code === '42703' || err.code === '42P01') {
      result = await queryRead(
        `SELECT DISTINCT location FROM (
           SELECT from_location AS location FROM trips WHERE LOWER(from_location) LIKE LOWER($1)
           UNION
           SELECT to_location AS location FROM trips WHERE LOWER(to_location) LIKE LOWER($1)
         ) AS locations
         LIMIT 30`,
        [`%${q}%`]
      );
    } else {
      throw err;
    }
  }

  const dbLocations = result.rows.map(row => row.location);
  const matchingDefaults = UTTARAKHAND_LOCATIONS
    .filter(loc => loc.toLowerCase().includes(qLower))
    .filter(loc => !dbLocations.some(db => db.toLowerCase() === loc.toLowerCase()));

  const merged = [...dbLocations, ...matchingDefaults];
  const unique = [...new Map(merged.map(l => [l.toLowerCase(), l])).values()];

  // Smart ranking: exact → starts-with → word-boundary → contains
  unique.sort((a, b) => {
    const al = a.toLowerCase();
    const bl = b.toLowerCase();
    const aExact = al === qLower;
    const bExact = bl === qLower;
    if (aExact !== bExact) return aExact ? -1 : 1;
    const aStarts = al.startsWith(qLower);
    const bStarts = bl.startsWith(qLower);
    if (aStarts !== bStarts) return aStarts ? -1 : 1;
    const aWord = al.split(/\s+/).some(w => w.startsWith(qLower));
    const bWord = bl.split(/\s+/).some(w => w.startsWith(qLower));
    if (aWord !== bWord) return aWord ? -1 : 1;
    return al.localeCompare(bl);
  });

  ApiResponse.success(
    { suggestions: unique.slice(0, 15) },
    'Location suggestions'
  ).send(res);
});

/**
 * Get trip bookings (Driver only - for their own trips)
 * GET /api/trips/:id/bookings
 */
const getTripBookings = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
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

/**
 * Start trip (Driver only) - scheduled → in_progress
 * PUT /api/trips/:id/start
 *
 * Auto-cancels any remaining pending bookings (driver didn't respond in time),
 * restores their seats, and notifies affected passengers.
 */
const startTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;

  let cancelledBookings = [];

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tripResult = await client.query(
      'SELECT id, status, departure_time, created_source FROM trips WHERE id = $1 AND driver_id = $2 FOR UPDATE',
      [tripId, driverId]
    );

    if (tripResult.rows.length === 0) {
      await client.query('ROLLBACK');
      throw ApiError.notFound('Trip not found');
    }

    const trip = tripResult.rows[0];
    if (trip.status !== 'scheduled') {
      await client.query('ROLLBACK');
      throw ApiError.badRequest(`Cannot start trip. Current status: ${trip.status}. Only scheduled trips can be started.`);
    }

    if (trip.created_source === 'independent_driver' && trip.departure_time && new Date(trip.departure_time).getTime() > Date.now()) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Independent ride auto-start hoti hai departure time pe. Manually start nahi kar sakte.');
    }

    const pending = await client.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
         cancellation_reason = 'auto-expired-trip-started'
       WHERE trip_id = $1 AND status = 'pending'
       RETURNING id, passenger_id, seat_numbers`,
      [tripId]
    );
    cancelledBookings = pending.rows;

    let restoredSeats = 0;
    for (const row of cancelledBookings) {
      restoredSeats += Array.isArray(row.seat_numbers) ? row.seat_numbers.length : 0;
    }
    if (restoredSeats > 0) {
      await client.query(
        'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
        [restoredSeats, tripId]
      );
    }

    try {
      await client.query(
        `UPDATE trips SET status = 'in_progress', started_at = COALESCE(started_at, NOW()) WHERE id = $1`,
        [tripId]
      );
    } catch (err) {
      if (err.code === '42703') {
        await client.query("UPDATE trips SET status = 'in_progress' WHERE id = $1", [tripId]);
      } else {
        throw err;
      }
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  for (const row of cancelledBookings) {
    try {
      const dataJson = JSON.stringify({ booking_id: row.id, trip_id: tripId });
      const n = await pool.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'booking_auto_cancelled',
           'Booking not confirmed',
           'Your booking was auto-cancelled because the driver started the ride without confirming your request.',
           $2::jsonb)
         RETURNING id, user_id, type, title, body, data, created_at, is_read`,
        [row.passenger_id, dataJson]
      );
      if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
    } catch (_) {}
  }
  if (cancelledBookings.length > 0) {
    emitTripUpdated(tripId, { reason: 'trip_started_pending_cancelled' });
  }

  ApiResponse.success(
    { status: 'in_progress', pendingBookingsCancelled: cancelledBookings.length },
    cancelledBookings.length > 0
      ? `Ride started. ${cancelledBookings.length} pending booking(s) were auto-cancelled.`
      : 'Ride started'
  ).send(res);
});

/**
 * Complete trip (Driver only) - in_progress → completed
 * PUT /api/trips/:id/complete
 */
const completeTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tripResult = await client.query(
      'SELECT id, status, departure_time FROM trips WHERE id = $1 AND driver_id = $2 FOR UPDATE',
      [tripId, driverId]
    );

    if (tripResult.rows.length === 0) {
      await client.query('ROLLBACK');
      throw ApiError.notFound('Trip not found');
    }

    const trip = tripResult.rows[0];
    if (trip.status !== 'in_progress' && trip.status !== 'scheduled') {
      await client.query('ROLLBACK');
      throw ApiError.badRequest(
        `Cannot complete trip. Current status: ${trip.status}. Only scheduled or in-progress trips can be completed.`
      );
    }

    if (trip.departure_time && new Date(trip.departure_time).getTime() > Date.now()) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Cannot complete ride before departure time.');
    }

    await client.query(
      "UPDATE trips SET status = 'completed' WHERE id = $1",
      [tripId]
    );

    await client.query(
      `UPDATE bookings SET status = 'completed'
       WHERE trip_id = $1 AND status = 'confirmed'`,
      [tripId]
    );

    const pendingOnComplete = await client.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
         cancellation_reason = 'auto-expired-trip-completed'
       WHERE trip_id = $1 AND status = 'pending'
       RETURNING id, passenger_id, seat_numbers`,
      [tripId]
    );

    let restoredSeats = 0;
    for (const row of pendingOnComplete.rows) {
      restoredSeats += Array.isArray(row.seat_numbers) ? row.seat_numbers.length : 0;
    }
    if (restoredSeats > 0) {
      await client.query(
        'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
        [restoredSeats, tripId]
      );
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  ApiResponse.success(
    { status: 'completed' },
    'Ride completed'
  ).send(res);
});

const DRIVER_CANCEL_WINDOW_DAYS = 30;
const DRIVER_CANCEL_MAX = 5;
const DRIVER_CANCEL_BLOCK_HOURS = 48;
const DRIVER_PERM_BLOCK_WINDOW_DAYS = 90;
const DRIVER_PERM_BLOCK_MAX = 12;

const cancelTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;

  try {
    const blockCheck = await pool.query(
      `SELECT cancel_blocked_until FROM users WHERE id = $1`,
      [driverId]
    );
    if (blockCheck.rows[0]?.cancel_blocked_until && new Date(blockCheck.rows[0].cancel_blocked_until) > new Date()) {
      const until = new Date(blockCheck.rows[0].cancel_blocked_until);
      throw ApiError.badRequest(
        'Aapne recently bahut baar ride cancel ki hai. Kuch samay baad try karein.'
      );
    }
  } catch (e) {
    if (e.statusCode) throw e;
    if (e.code !== '42703') logger.warn('Cancel block check failed:', e.message);
  }

  const client = await pool.connect();
  let notifyPassengers = [];
  let cancelledBookingIds = [];
  let confirmedPassengerIds = [];
  try {
    await client.query('BEGIN');

    const tripResult = await client.query(
      'SELECT id, status, departure_time, driver_id, created_at FROM trips WHERE id = $1 AND driver_id = $2 FOR UPDATE',
      [tripId, driverId]
    );

    if (tripResult.rows.length === 0) {
      await client.query('ROLLBACK');
      throw ApiError.notFound('Trip not found');
    }

    const trip = tripResult.rows[0];
    if (trip.status === 'cancelled' || trip.status === 'completed') {
      await client.query('ROLLBACK');
      throw ApiError.badRequest(`Trip is already ${trip.status}. Cannot cancel.`);
    }
    if (trip.status === 'in_progress') {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Ride has already started. Cancellation not allowed.');
    }

    const departureTimeMs = new Date(trip.departure_time).getTime();
    const now = Date.now();
    if (now >= departureTimeMs) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Ride start time has passed. Cancellation not allowed.');
    }

    const allActiveBookings = await client.query(
      `SELECT id, passenger_id, seat_numbers, status FROM bookings WHERE trip_id = $1 AND status IN ('pending', 'confirmed')`,
      [tripId]
    );
    const confirmedRows = allActiveBookings.rows.filter(r => r.status === 'confirmed');
    cancelledBookingIds = confirmedRows.map(r => r.id);
    confirmedPassengerIds = confirmedRows.map(r => ({ passenger_id: r.passenger_id, booking_id: r.id }));

    await client.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(), cancellation_reason = 'Driver cancelled the trip' WHERE trip_id = $1 AND status IN ('pending', 'confirmed')`,
      [tripId]
    );

    let seatsToRelease = 0;
    for (const row of allActiveBookings.rows) {
      const seats = Array.isArray(row.seat_numbers) ? row.seat_numbers : [];
      seatsToRelease += seats.length;
    }

    if (seatsToRelease > 0) {
      await client.query(
        'UPDATE trips SET available_seats = available_seats + $1, status = $3 WHERE id = $2',
        [seatsToRelease, tripId, 'cancelled']
      );
    } else {
      await client.query(
        "UPDATE trips SET status = 'cancelled' WHERE id = $1",
        [tripId]
      );
    }

    if (allActiveBookings.rows.length > 0) {
      const placeholders = allActiveBookings.rows
        .map((_, i) => `($${i + 1}, 'trip_cancelled', 'Ride cancelled', 'The driver cancelled this ride. You are not charged.')`)
        .join(', ');
      const flatParams = allActiveBookings.rows.map(r => r.passenger_id);
      try {
        const nIns = await client.query(
          `INSERT INTO notifications (user_id, type, title, body) VALUES ${placeholders}
           RETURNING id, user_id, type, title, body, created_at, is_read`,
          flatParams
        );
        notifyPassengers = nIns.rows;
      } catch (e) {
        logger.warn('Batch passenger cancel notification failed:', e.message);
      }
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  if (cancelledBookingIds.length > 0) {
    try {
      await pool.query('DELETE FROM pending_rate_notifications WHERE booking_id = ANY($1::uuid[])', [cancelledBookingIds]);
    } catch (e) {
      if (e.code !== '42P01') logger.warn('Rate notification cleanup failed:', e.message);
    }
  }

  for (const row of notifyPassengers) {
    emitNotificationToUser(row.user_id, row);
  }

  for (const { passenger_id, booking_id } of confirmedPassengerIds) {
    try {
      await pool.query(
        `INSERT INTO ride_ratings (booking_id, from_user_id, rated_user_id, from_role, rating, comment)
         VALUES ($1, $2, $3, 'passenger', 1, 'Auto-rating: Driver ne ride cancel ki.')
         ON CONFLICT DO NOTHING`,
        [booking_id, passenger_id, driverId]
      );
    } catch (e) {
      if (e.code !== '42P01') logger.warn('Auto 1-star for driver failed:', e.message);
    }
    try {
      const rn = await pool.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'rate_ride', 'Rate your driver', 'Driver ne ride cancel ki. Apna experience share karein.', $2::jsonb)
         RETURNING id, user_id, type, title, body, data, created_at, is_read`,
        [passenger_id, JSON.stringify({ booking_id, trip_id: tripId, rate_only: 'driver' })]
      );
      if (rn.rows[0]) emitNotificationToUser(rn.rows[0].user_id, rn.rows[0]);
    } catch (e) {
      logger.warn('Cancel rate notification (passenger) failed:', e.message);
    }
  }

  emitTripUpdated(tripId, { reason: 'driver_cancelled_trip' });

  logger.info(`Trip cancelled: ${tripId} by driver ${driverId}`);

  try {
    const countRes = await pool.query(
      `SELECT
         (SELECT COUNT(*)::int FROM trips WHERE driver_id = $1 AND status = 'cancelled' AND updated_at > NOW() - ($2::int * INTERVAL '1 day')) AS recent,
         (SELECT COUNT(*)::int FROM trips WHERE driver_id = $1 AND status = 'cancelled' AND updated_at > NOW() - ($3::int * INTERVAL '1 day')) AS long_term`,
      [driverId, DRIVER_CANCEL_WINDOW_DAYS, DRIVER_PERM_BLOCK_WINDOW_DAYS]
    );
    const recent = countRes.rows[0]?.recent || 0;
    const longTerm = countRes.rows[0]?.long_term || 0;
    if (longTerm >= DRIVER_PERM_BLOCK_MAX) {
      await pool.query(
        `UPDATE users SET cancel_blocked_until = '2099-12-31'::timestamp, cancel_count = $2
         WHERE id = $1`,
        [driverId, longTerm]
      );
      logger.info(`Driver ${driverId} PERMANENTLY blocked (${longTerm} cancels in ${DRIVER_PERM_BLOCK_WINDOW_DAYS}d)`);
    } else if (recent >= DRIVER_CANCEL_MAX) {
      await pool.query(
        `UPDATE users SET cancel_blocked_until = NOW() + ($2::int * INTERVAL '1 hour'), cancel_count = $3
         WHERE id = $1`,
        [driverId, DRIVER_CANCEL_BLOCK_HOURS, recent]
      );
      logger.info(`Driver ${driverId} temp-blocked ${DRIVER_CANCEL_BLOCK_HOURS}h (${recent} cancels in ${DRIVER_CANCEL_WINDOW_DAYS}d)`);
    }
  } catch (e) {
    if (e.code !== '42703') logger.warn('Cancel tracking failed:', e.message);
  }

  ApiResponse.success(
    { status: 'cancelled' },
    'Trip cancelled. Passengers have been notified.'
  ).send(res);
});

/**
 * Delete trip (Driver only)
 * Allowed ONLY within 1 hour of creation AND no confirmed/pending bookings.
 * After 1 hour the ride is permanent — use cancel instead.
 * DELETE /api/trips/:id
 */
const DELETE_WINDOW_HOURS = 1;

const deleteTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const tripResult = await client.query(
      'SELECT id, created_at FROM trips WHERE id = $1 AND driver_id = $2 FOR UPDATE',
      [tripId, driverId]
    );

    if (tripResult.rows.length === 0) {
      throw ApiError.notFound('Trip not found');
    }

    const createdAt = new Date(tripResult.rows[0].created_at);
    const hoursSinceCreation = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60);
    if (hoursSinceCreation > DELETE_WINDOW_HOURS) {
      throw ApiError.badRequest(
        `Ride sirf banane ke ${DELETE_WINDOW_HOURS} ghante ke andar delete ho sakti hai. Uske baad cancel karein.`
      );
    }

    const bookingsCheck = await client.query(
      `SELECT status FROM bookings
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

    await client.query('DELETE FROM bookings WHERE trip_id = $1', [tripId]);
    await client.query('DELETE FROM trips WHERE id = $1', [tripId]);

    await client.query('COMMIT');

    logger.info(`Trip deleted: ${tripId} by driver ${driverId}`);

    ApiResponse.success({ deleted: true }, 'Ride deleted successfully').send(res);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
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
