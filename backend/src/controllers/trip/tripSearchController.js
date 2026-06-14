const { pool, queryRead } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const retentionConfig = require('../../config/retentionConfig');
const toTitleCase = require('../../utils/titleCase');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function requireUuid(id) {
  if (!id || !UUID_RE.test(id)) throw ApiError.badRequest('Invalid trip ID');
}

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

  const withTimeout = (promise, ms) =>
    Promise.race([
      promise,
      new Promise((_, reject) => setTimeout(() => reject(new Error('Query timeout')), ms)),
    ]);

  const [_tripsSettled, _unionSettled] = await Promise.allSettled([
    withTimeout(runTripsQuery(), 8000),
    withTimeout(runUnionQuery(), 8000),
  ]);
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
      phone: null,
      whatsapp_number: null,
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

/**
 * Get location suggestions
 * GET /api/trips/locations?q=Deh
 */
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

module.exports = {
  searchTrips,
  getTripBookedSeats,
  getRecentRoutes,
  saveRecentRoute,
  getLocationSuggestions,
};
