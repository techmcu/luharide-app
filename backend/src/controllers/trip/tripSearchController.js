const { pool, queryRead } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const retentionConfig = require('../../config/retentionConfig');
const toTitleCase = require('../../utils/titleCase');
const olaMaps = require('../../services/olaMapsService');

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

/** Lat/lng bounding box for a radius (km) — used as an indexed SQL pre-filter. */
function geoBoundingBox(lat, lng, radiusKm) {
  const dLat = radiusKm / 111; // ~111 km per degree latitude
  const cos = Math.max(0.1, Math.cos((lat * Math.PI) / 180));
  const dLng = radiusKm / (111 * cos);
  return { latMin: lat - dLat, latMax: lat + dLat, lngMin: lng - dLng, lngMax: lng + dLng };
}

/**
 * Proximity + rating search — used when the app sends origin coordinates.
 * Ranks rides by "nearness to you" combined with driver rating, so the closest
 * well-rated rides surface first (concentric-circle idea). Backward compatible:
 * exact-text search still runs when no coordinates are provided.
 *
 * Ranking: score = 0.7·(distance, normalised) + 0.3·(1 − rating/5)  [lower = better]
 * Tie-break: KYC-verified driver → more ratings (experience) → earlier departure.
 * Radius auto-scales with route length (short trip → tight radius, long → wide).
 */
async function proximitySearch(req, res, q, fLat, fLng) {
  const dateStr = (q.date != null ? String(q.date) : '').trim().slice(0, 10);
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
    throw ApiError.badRequest('Invalid date. Use YYYY-MM-DD (e.g. 2026-02-23).');
  }
  const tLat = parseFloat(q.to_lat);
  const tLng = parseFloat(q.to_lng);
  const hasDest = olaMaps.isValidLatLng(tLat, tLng);

  // Auto radius: ~35% of straight-line route length, clamped 8–60 km.
  let radius = 25;
  if (hasDest) {
    const routeKm = olaMaps.haversineKm(fLat, fLng, tLat, tLng);
    if (Number.isFinite(routeKm)) radius = Math.min(60, Math.max(8, Math.round(routeKm * 0.35)));
  }
  const bb = geoBoundingBox(fLat, fLng, radius);

  const graceMin = retentionConfig.tripSearchGraceMinutesAfterDeparture;
  const CAND_LIMIT = 200; // bound work on a small VPS; we score+sort in JS
  const RATING_DEFAULT = 3.0; // neutral baseline for unrated drivers (not buried, not boosted)
  const DEST_SLACK = 1.5; // a ride's destination may be up to radius·1.5 from yours

  const limit = Math.min(80, Math.max(1, parseInt(q.limit, 10) || 40));
  const offset = Math.min(400, Math.max(0, parseInt(q.offset, 10) || 0));

  // Corridor ("along-route") tolerance: a ride matches if BOTH your points sit
  // within corridorKm of its route line, in travel order — the precise BlaBlaCar
  // "passing through" match. Padding (degrees) for the indexed bbox pre-filter.
  const corridorKm = Math.min(12, Math.max(3, Math.round(radius * 0.2)));
  const padLat = corridorKm / 111;
  const padLng = corridorKm / (111 * Math.max(0.1, Math.cos((fLat * Math.PI) / 180)));
  const maxRef = radius + (hasDest ? radius * DEST_SLACK : 0) || radius;

  // Text fallback: ALSO match rides by from/to text so a ride is findable even
  // if it has no coordinates yet (created via text, or before migration). This
  // fixes "I created a ride but search can't find it" when searching by coords.
  const normLoc = (s) => String(s || '').toLowerCase().replace(/[\s,.\-_:;/\\]+/g, '');
  const fromText = (q.from != null ? String(q.from) : q.from_location != null ? String(q.from_location) : '').trim();
  const toText = (q.to != null ? String(q.to) : q.to_location != null ? String(q.to_location) : '').trim();
  const fromPat = `%${normLoc(fromText)}%`;
  const toPat = `%${normLoc(toText)}%`;
  const hasText = normLoc(fromText).length >= 2 && normLoc(toText).length >= 2;

  const parsePoly = (v) => {
    if (Array.isArray(v)) return v;
    if (typeof v === 'string') { try { return JSON.parse(v); } catch { return null; } }
    return null;
  };

  const RATING_SUB = `LEFT JOIN (
      SELECT rated_user_id, AVG(rating)::float AS avg_rating, COUNT(*)::int AS cnt
      FROM ride_ratings GROUP BY rated_user_id
    ) rr ON rr.rated_user_id = t.driver_id`;
  const TRIP_GEO_COLS = `t.from_lat, t.from_lng, t.to_lat, t.to_lng, t.route_polyline,
      COALESCE(rr.avg_rating, 0) AS driver_rating, COALESCE(rr.cnt, 0) AS driver_rating_count`;
  const TRIP_TIME_WHERE = `t.departure_time >= ($5::date)::timestamp
      AND t.departure_time <  ($5::date)::timestamp + interval '1 day'
      AND COALESCE(t.available_seats, t.total_capacity, 0) > 0
      AND t.departure_time > (NOW() AT TIME ZONE 'UTC') - (${graceMin} * INTERVAL '1 minute')`;

  // ── Independent-driver trips: endpoint-proximity + corridor candidates ──
  const tripQueries = [
    // (a) endpoint: ride origin near your origin
    queryRead(
      `SELECT ${_TRIP_COLS}, ${_DRIVER_COLS}, ${TRIP_GEO_COLS}
       FROM trips t LEFT JOIN users u ON t.driver_id = u.id ${RATING_SUB}
       WHERE t.status = 'scheduled'
         AND t.from_lat BETWEEN $1 AND $2 AND t.from_lng BETWEEN $3 AND $4
         AND ${TRIP_TIME_WHERE}
       LIMIT ${CAND_LIMIT}`,
      [bb.latMin, bb.latMax, bb.lngMin, bb.lngMax, dateStr]
    ).catch((e) => { if (e.code !== '42703' && e.code !== '42P01') logger.warn('Endpoint trips query failed:', e.message); return { rows: [] }; }),
  ];
  // (b) corridor: ride route passes near BOTH your points (needs a destination)
  if (hasDest) {
    tripQueries.push(
      queryRead(
        `SELECT ${_TRIP_COLS}, ${_DRIVER_COLS}, ${TRIP_GEO_COLS}
         FROM trips t LEFT JOIN users u ON t.driver_id = u.id ${RATING_SUB}
         WHERE t.status = 'scheduled' AND t.route_polyline IS NOT NULL
           AND (t.route_min_lat - $6) <= $7 AND (t.route_max_lat + $6) >= $7
           AND (t.route_min_lng - $8) <= $9 AND (t.route_max_lng + $8) >= $9
           AND (t.route_min_lat - $6) <= $10 AND (t.route_max_lat + $6) >= $10
           AND (t.route_min_lng - $8) <= $11 AND (t.route_max_lng + $8) >= $11
           AND ${TRIP_TIME_WHERE}
         LIMIT ${CAND_LIMIT}`,
        [bb.latMin, bb.latMax, bb.lngMin, bb.lngMax, dateStr,
         padLat, fLat, padLng, fLng, tLat, tLng]
      ).catch((e) => { if (e.code !== '42703' && e.code !== '42P01') logger.warn('Corridor trips query failed:', e.message); return { rows: [] }; })
    );
  }
  const tripResults = await Promise.all(tripQueries);

  // (c) text match (from/to names) — guarantees findability for non-geo rides.
  let textRows = [];
  if (hasText) {
    try {
      const tr = await queryRead(
        `SELECT ${_TRIP_COLS}, ${_DRIVER_COLS}, ${TRIP_GEO_COLS}
         FROM trips t LEFT JOIN users u ON t.driver_id = u.id ${RATING_SUB}
         WHERE t.status = 'scheduled'
           AND t.from_location_norm LIKE $2 AND t.to_location_norm LIKE $3
           AND t.departure_time >= ($1::date)::timestamp
           AND t.departure_time <  ($1::date)::timestamp + interval '1 day'
           AND COALESCE(t.available_seats, t.total_capacity, 0) > 0
           AND t.departure_time > (NOW() AT TIME ZONE 'UTC') - (${graceMin} * INTERVAL '1 minute')
         LIMIT ${CAND_LIMIT}`,
        [dateStr, fromPat, toPat]
      );
      textRows = tr.rows;
    } catch (e) {
      if (e.code !== '42703' && e.code !== '42P01') logger.warn('Text trips query failed:', e.message);
    }
  }

  // Merge unique rides; evaluate each as corridor (preferred) / endpoint / text.
  const tripById = new Map();
  for (const rs of tripResults) for (const row of rs.rows) if (!tripById.has(row.id)) tripById.set(row.id, row);
  const textIds = new Set();
  for (const row of textRows) { textIds.add(row.id); if (!tripById.has(row.id)) tripById.set(row.id, row); }

  const scored = [];
  for (const t of tripById.values()) {
    let matchType = null, geoDist = Infinity, displayDist = Infinity, exactDest = false;

    // Corridor: both points close to the route line, origin before destination.
    if (hasDest) {
      const poly = parsePoly(t.route_polyline);
      if (poly && poly.length >= 2) {
        const o = olaMaps.projectOntoPolyline(fLat, fLng, poly);
        const d = olaMaps.projectOntoPolyline(tLat, tLng, poly);
        if (o.distKm <= corridorKm && d.distKm <= corridorKm && o.alongKm < d.alongKm) {
          matchType = 'corridor';
          geoDist = o.distKm + d.distKm;
          displayDist = o.distKm;
          exactDest = d.distKm <= 3;
        }
      }
    }

    // Endpoint: ride origin within radius (+ destination within slack).
    if (!matchType && t.from_lat != null && t.from_lng != null) {
      const oDist = olaMaps.haversineKm(fLat, fLng, Number(t.from_lat), Number(t.from_lng));
      if (Number.isFinite(oDist) && oDist <= radius) {
        let dDist = null;
        let ok = true;
        if (hasDest && t.to_lat != null && t.to_lng != null) {
          dDist = olaMaps.haversineKm(tLat, tLng, Number(t.to_lat), Number(t.to_lng));
          if (Number.isFinite(dDist) && dDist > radius * DEST_SLACK) ok = false; // wrong direction
          else exactDest = dDist <= 3;
        }
        if (ok) {
          matchType = 'endpoint';
          geoDist = oDist + (dDist != null ? dDist : 0);
          displayDist = oDist;
        }
      }
    }

    // Text fallback: name matched but no usable geo → still show it (findability).
    if (!matchType) {
      if (textIds.has(t.id)) {
        matchType = 'text';
        geoDist = maxRef; // ranks below geo matches but stays visible
        displayDist = null;
      } else {
        continue; // geo candidate that didn't qualify and didn't text-match
      }
    }

    const distNorm = Math.min(1, geoDist / maxRef);
    const rating = t.driver_rating_count > 0 ? Number(t.driver_rating) : RATING_DEFAULT;
    const ratingNorm = 1 - Math.min(1, Math.max(0, rating) / 5);
    // Corridor (true "passing through") gets a small edge over endpoint matches.
    const score = 0.7 * distNorm + 0.3 * ratingNorm + (matchType === 'endpoint' ? 0.05 : 0);
    scored.push({ t, displayDist, score, matchType, exactDest });
  }

  scored.sort((a, b) => {
    if (a.score !== b.score) return a.score - b.score;
    const av = a.t.driver_verified === 'approved' ? 0 : 1;
    const bv = b.t.driver_verified === 'approved' ? 0 : 1;
    if (av !== bv) return av - bv;
    if (a.t.driver_rating_count !== b.t.driver_rating_count) {
      return b.t.driver_rating_count - a.t.driver_rating_count;
    }
    return new Date(a.t.departure_time) - new Date(b.t.departure_time);
  });

  const trips = scored.slice(offset, offset + limit).map(({ t, displayDist, matchType, exactDest }) => ({
    id: t.id,
    from_location: t.from_location,
    to_location: t.to_location,
    departure_time: t.departure_time,
    arrival_time: t.arrival_time,
    fare_per_seat: t.fare_per_seat,
    available_seats: t.available_seats ?? t.total_capacity ?? 0,
    total_seats: t.total_capacity ?? 0,
    vehicle_number: t.vehicle_number,
    vehicle_model_id: t.vehicle_model_id ?? null,
    stops: t.stops,
    status: t.status,
    distance_from_you_km: displayDist != null ? Math.round(displayDist * 10) / 10 : null,
    match_type: matchType, // 'corridor' | 'endpoint' | 'text'
    match_quality: matchType === 'text' ? null : (exactDest ? 'green' : 'orange'),
    driver: {
      id: t.driver_id,
      name: t.driver_name,
      phone: null,
      whatsapp_number: null,
      isVerified: t.driver_verified === 'approved',
      bio: t.driver_bio ?? null,
      average_rating: t.driver_rating_count > 0 ? Math.round(Number(t.driver_rating) * 10) / 10 : 0,
      total_ratings: t.driver_rating_count,
      luggage_allowance_per_passenger: t.luggage_allowance_per_passenger ?? null,
    },
  }));

  // ── Union rides: endpoint + corridor (union drivers have no per-user ratings) ──
  const UNION_COLS = `s.id, s.from_location, s.to_location, s.departure_time, s.status,
      s.from_lat, s.from_lng, s.to_lat, s.to_lng, s.route_polyline,
      d.name AS driver_name, d.vehicle_number, d.phone, d.whatsapp_number,
      u.name AS union_name, s.union_driver_id, s.union_id`;
  const UNION_JOIN = `FROM union_schedules s
      JOIN union_drivers d ON d.id = s.union_driver_id
      JOIN unions u ON u.id = s.union_id`;
  const UNION_TIME_WHERE = `s.departure_time >= ($5::date)::timestamp
      AND s.departure_time <  ($5::date)::timestamp + interval '1 day'
      AND s.departure_time > (NOW() AT TIME ZONE 'UTC') - (${graceMin} * INTERVAL '1 minute')`;

  const unionQueries = [
    queryRead(
      `SELECT ${UNION_COLS} ${UNION_JOIN}
       WHERE s.status = 'scheduled'
         AND s.from_lat BETWEEN $1 AND $2 AND s.from_lng BETWEEN $3 AND $4
         AND ${UNION_TIME_WHERE}
       LIMIT ${CAND_LIMIT}`,
      [bb.latMin, bb.latMax, bb.lngMin, bb.lngMax, dateStr]
    ).catch((e) => { if (e.code !== '42703' && e.code !== '42P01') logger.warn('Endpoint union query failed:', e.message); return { rows: [] }; }),
  ];
  if (hasDest) {
    unionQueries.push(
      queryRead(
        `SELECT ${UNION_COLS} ${UNION_JOIN}
         WHERE s.status = 'scheduled' AND s.route_polyline IS NOT NULL
           AND (s.route_min_lat - $6) <= $7 AND (s.route_max_lat + $6) >= $7
           AND (s.route_min_lng - $8) <= $9 AND (s.route_max_lng + $8) >= $9
           AND (s.route_min_lat - $6) <= $10 AND (s.route_max_lat + $6) >= $10
           AND (s.route_min_lng - $8) <= $11 AND (s.route_max_lng + $8) >= $11
           AND ${UNION_TIME_WHERE}
         LIMIT ${CAND_LIMIT}`,
        [bb.latMin, bb.latMax, bb.lngMin, bb.lngMax, dateStr,
         padLat, fLat, padLng, fLng, tLat, tLng]
      ).catch((e) => { if (e.code !== '42703' && e.code !== '42P01') logger.warn('Corridor union query failed:', e.message); return { rows: [] }; })
    );
  }
  // Union text fallback (findability for non-geo union rides).
  let unionTextRows = [];
  if (hasText) {
    try {
      const utr = await queryRead(
        `SELECT ${UNION_COLS} ${UNION_JOIN}
         WHERE s.status = 'scheduled'
           AND s.from_location_norm LIKE $2 AND s.to_location_norm LIKE $3
           AND s.departure_time >= ($1::date)::timestamp
           AND s.departure_time <  ($1::date)::timestamp + interval '1 day'
           AND s.departure_time > (NOW() AT TIME ZONE 'UTC') - (${graceMin} * INTERVAL '1 minute')
         LIMIT ${CAND_LIMIT}`,
        [dateStr, fromPat, toPat]
      );
      unionTextRows = utr.rows;
    } catch (e) {
      if (e.code !== '42703' && e.code !== '42P01') logger.warn('Text union query failed:', e.message);
    }
  }

  const unionResults = await Promise.all(unionQueries);
  const unionById = new Map();
  for (const rs of unionResults) for (const row of rs.rows) if (!unionById.has(row.id)) unionById.set(row.id, row);
  const unionTextIds = new Set();
  for (const row of unionTextRows) { unionTextIds.add(row.id); if (!unionById.has(row.id)) unionById.set(row.id, row); }

  const unionScored = [];
  for (const s of unionById.values()) {
    let matchType = null, geoDist = Infinity, displayDist = null, exactDest = false;
    if (hasDest) {
      const poly = parsePoly(s.route_polyline);
      if (poly && poly.length >= 2) {
        const o = olaMaps.projectOntoPolyline(fLat, fLng, poly);
        const d = olaMaps.projectOntoPolyline(tLat, tLng, poly);
        if (o.distKm <= corridorKm && d.distKm <= corridorKm && o.alongKm < d.alongKm) {
          matchType = 'corridor'; geoDist = o.distKm + d.distKm; displayDist = o.distKm; exactDest = d.distKm <= 3;
        }
      }
    }
    if (!matchType && s.from_lat != null && s.from_lng != null) {
      const oDist = olaMaps.haversineKm(fLat, fLng, Number(s.from_lat), Number(s.from_lng));
      if (Number.isFinite(oDist) && oDist <= radius) {
        let ok = true;
        if (hasDest && s.to_lat != null && s.to_lng != null) {
          const dDist = olaMaps.haversineKm(tLat, tLng, Number(s.to_lat), Number(s.to_lng));
          if (Number.isFinite(dDist) && dDist > radius * DEST_SLACK) ok = false;
          else exactDest = dDist <= 3;
        }
        if (ok) { matchType = 'endpoint'; geoDist = oDist; displayDist = oDist; }
      }
    }
    if (!matchType) {
      if (unionTextIds.has(s.id)) { matchType = 'text'; geoDist = maxRef; displayDist = null; }
      else continue;
    }
    unionScored.push({ s, displayDist, geoDist, matchType, exactDest });
  }
  unionScored.sort((a, b) => a.geoDist - b.geoDist);

  const unionRides = unionScored.slice(offset, offset + limit).map(({ s, displayDist, matchType, exactDest }) => ({
    id: s.id,
    from_location: s.from_location,
    to_location: s.to_location,
    departure_time: s.departure_time,
    status: s.status,
    driver_name: s.driver_name,
    vehicle_number: s.vehicle_number,
    phone: s.phone,
    whatsapp_number: s.whatsapp_number,
    union_name: s.union_name,
    union_driver_id: s.union_driver_id,
    union_id: s.union_id,
    distance_from_you_km: displayDist != null ? Math.round(displayDist * 10) / 10 : null,
    match_type: matchType,
    match_quality: matchType === 'text' ? null : (exactDest ? 'green' : 'orange'),
  }));

  return ApiResponse.success(
    {
      trips,
      count: trips.length,
      unionRides,
      union_count: unionRides.length,
      search_radius_km: radius,
      mode: 'proximity',
      pagination: { limit, offset, max_limit: 80, max_offset: 400 },
    },
    'Nearby rides found'
  ).send(res);
}

/**
 * Search trips
 * GET /api/trips/search?from=Dehradun&to=Purola&date=2026-02-23
 * or GET /api/trips/search?route_id=uuid&date=2026-02-23 (canonical route-based search)
 * or GET /api/trips/search?from_lat=&from_lng=&to_lat=&to_lng=&date= (proximity + rating)
 * Params from query (GET) or body (POST). Aliases: from_location→from, to_location→to.
 */
const searchTrips = asyncHandler(async (req, res) => {
  const q = { ...req.query, ...(req.body && typeof req.body === 'object' ? req.body : {}) };

  // Proximity path: when origin coordinates are present, rank by nearness +
  // rating instead of exact text match.
  const pfLat = parseFloat(q.from_lat);
  const pfLng = parseFloat(q.from_lng);
  if (olaMaps.isValidLatLng(pfLat, pfLng)) {
    return proximitySearch(req, res, q, pfLat, pfLng);
  }
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

  const suggestions = unique.slice(0, 15);

  // Enrich with Ola Maps autocomplete so the app can get coordinates for each
  // place (needed for distance/fare/proximity). Best-effort: if Ola is disabled
  // or fails it returns [] and we fall back to coordinate-less suggestions.
  let olaPlaces = [];
  try {
    olaPlaces = await olaMaps.autocomplete(qLower);
  } catch (_) { /* never blocks suggestions */ }

  // `places` = unified list with coords where available. Ola entries (with
  // lat/lng) first, then any local suggestion not already covered (null coords).
  const seen = new Set();
  const places = [];
  for (const p of olaPlaces) {
    const k = p.description.toLowerCase();
    if (seen.has(k)) continue;
    seen.add(k);
    places.push({ description: p.description, lat: p.lat ?? null, lng: p.lng ?? null });
  }
  for (const s of suggestions) {
    const k = s.toLowerCase();
    if (seen.has(k)) continue;
    seen.add(k);
    places.push({ description: s, lat: null, lng: null });
  }

  // Rank: exact → starts-with → word-starts → contains; then SHORTEST/simplest
  // name first (so "Dehradun" beats "Dehradun Railway Station, Paltan Bazar…").
  // As the query gets more specific, the matching simple name rises to the top.
  const rankScore = (desc) => {
    const d = desc.toLowerCase();
    if (d === qLower) return 0;
    if (d.startsWith(qLower)) return 1;
    if (d.split(/[\s,]+/).some((w) => w.startsWith(qLower))) return 2;
    return 3;
  };
  places.sort((a, b) => {
    const ra = rankScore(a.description);
    const rb = rankScore(b.description);
    if (ra !== rb) return ra - rb;
    // simpler = fewer commas, then shorter overall
    const ca = (a.description.match(/,/g) || []).length;
    const cb = (b.description.match(/,/g) || []).length;
    if (ca !== cb) return ca - cb;
    if (a.description.length !== b.description.length) return a.description.length - b.description.length;
    return a.description.localeCompare(b.description);
  });

  ApiResponse.success(
    { suggestions, places: places.slice(0, 15) },
    'Location suggestions'
  ).send(res);
});

/**
 * Estimate road distance + duration for a route (coords required).
 * GET /api/trips/estimate?from_lat=&from_lng=&to_lat=&to_lng=
 * Returns distance/time only — fare is computed/enforced server-side at create,
 * never exposed here (drivers shouldn't see a "suggested" price).
 */
const estimateRoute = asyncHandler(async (req, res) => {
  const fLat = parseFloat(req.query.from_lat);
  const fLng = parseFloat(req.query.from_lng);
  const tLat = parseFloat(req.query.to_lat);
  const tLng = parseFloat(req.query.to_lng);
  if (!olaMaps.isValidLatLng(fLat, fLng) || !olaMaps.isValidLatLng(tLat, tLng)) {
    throw ApiError.badRequest('Valid from_lat, from_lng, to_lat, to_lng are required.');
  }

  const route = await olaMaps.getRouteDistance({ lat: fLat, lng: fLng }, { lat: tLat, lng: tLng });
  if (!route) {
    throw ApiError.serviceUnavailable('Could not compute route distance right now.');
  }

  ApiResponse.success(
    {
      distance_km: route.distanceKm,
      duration_min: route.durationMin,
      estimated: route.estimated === true, // true = Haversine fallback, not road data
    },
    'Route estimate'
  ).send(res);
});

/**
 * Reverse geocode: GPS coordinates → human-readable place name.
 * GET /api/trips/reverse-geocode?lat=&lng=
 * Used by the app's "use my current location" feature to label the pickup.
 */
const reverseGeocode = asyncHandler(async (req, res) => {
  const lat = parseFloat(req.query.lat);
  const lng = parseFloat(req.query.lng);
  if (!olaMaps.isValidLatLng(lat, lng)) {
    throw ApiError.badRequest('Valid lat and lng are required.');
  }
  const name = await olaMaps.reverseGeocode(lat, lng);
  ApiResponse.success(
    { name: name || null, lat, lng },
    'Reverse geocode'
  ).send(res);
});

module.exports = {
  searchTrips,
  getTripBookedSeats,
  getRecentRoutes,
  saveRecentRoute,
  getLocationSuggestions,
  estimateRoute,
  reverseGeocode,
};
