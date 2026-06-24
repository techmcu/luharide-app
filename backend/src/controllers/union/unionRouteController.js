const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const toTitleCase = require('../../utils/titleCase');
const olaMaps = require('../../services/olaMapsService');

/**
 * Best-effort: fill a route's missing coords by geocoding its text, AFTER the
 * response (never blocks route creation). Ensures every route ends up with
 * lat/lng so union rides get coordinates for proximity (70/30) matching even
 * when the admin typed the place instead of picking it from autocomplete.
 */
async function _enrichRouteGeo(routeId, fromText, toText, fromCoord, toCoord) {
  try {
    let f = fromCoord, t = toCoord;
    if (!f || !t) {
      const [g1, g2] = await Promise.all([
        f ? null : olaMaps.geocode(fromText),
        t ? null : olaMaps.geocode(toText),
      ]);
      if (!f && g1) f = { lat: g1.lat, lng: g1.lng };
      if (!t && g2) t = { lat: g2.lat, lng: g2.lng };
    }
    if (!f && !t) return;
    await pool.query(
      `UPDATE union_routes
          SET from_lat = COALESCE(from_lat, $2), from_lng = COALESCE(from_lng, $3),
              to_lat   = COALESCE(to_lat,   $4), to_lng   = COALESCE(to_lng,   $5)
        WHERE id = $1`,
      [routeId, f?.lat ?? null, f?.lng ?? null, t?.lat ?? null, t?.lng ?? null]
    );
  } catch (e) {
    if (e.code !== '42703') logger.warn('Union route geo enrich failed:', e.message);
  }
}

const getUnionRoutes = asyncHandler(async (req, res) => {
  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }

  const unionId = resUnion.rows[0].union_id;
  let routesRes;
  try {
    routesRes = await pool.query(
      `SELECT id, from_location, to_location, from_lat, from_lng, to_lat, to_lng, is_active, created_at
       FROM union_routes
       WHERE union_id = $1 AND is_active = TRUE
       ORDER BY from_location, to_location`,
      [unionId]
    );
  } catch (e) {
    // Pre-migration DB without coord columns — fall back to base columns.
    if (e.code !== '42703') throw e;
    routesRes = await pool.query(
      `SELECT id, from_location, to_location, is_active, created_at
       FROM union_routes
       WHERE union_id = $1 AND is_active = TRUE
       ORDER BY from_location, to_location`,
      [unionId]
    );
  }

  ApiResponse.success(
    { routes: routesRes.rows, count: routesRes.rows.length },
    'Union routes retrieved'
  ).send(res);
});

const addUnionRoute = asyncHandler(async (req, res) => {
  const { from_location, to_location, from_lat, from_lng, to_lat, to_lng } = req.body;

  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }

  const unionId = resUnion.rows[0].union_id;
  const validCoord = (la, ln) =>
    Number.isFinite(la) && Number.isFinite(ln) && la >= -90 && la <= 90 && ln >= -180 && ln <= 180;
  const fLat = parseFloat(from_lat), fLng = parseFloat(from_lng);
  const tLat = parseFloat(to_lat), tLng = parseFloat(to_lng);
  const haveFrom = validCoord(fLat, fLng);
  const haveTo = validCoord(tLat, tLng);

  let insertRes;
  try {
    insertRes = await pool.query(
      `INSERT INTO union_routes (union_id, from_location, to_location, from_lat, from_lng, to_lat, to_lng, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, TRUE)
       RETURNING *`,
      [unionId, toTitleCase(from_location), toTitleCase(to_location),
       haveFrom ? fLat : null, haveFrom ? fLng : null, haveTo ? tLat : null, haveTo ? tLng : null]
    );
  } catch (e) {
    // Pre-migration DB without coord columns — store text only.
    if (e.code !== '42703') throw e;
    insertRes = await pool.query(
      `INSERT INTO union_routes (union_id, from_location, to_location, is_active)
       VALUES ($1, $2, $3, TRUE)
       RETURNING *`,
      [unionId, toTitleCase(from_location), toTitleCase(to_location)]
    );
  }

  const route = insertRes.rows[0];
  logger.info(`Union route added ${route.id} for union ${unionId} by admin ${req.user.id}`);

  ApiResponse.created(
    { route },
    'Route added for union'
  ).send(res);

  // Background: ensure the route has coords (geocode the text if the admin
  // didn't pick from autocomplete) so rides built from it support proximity.
  if (!haveFrom || !haveTo) {
    _enrichRouteGeo(
      route.id, from_location, to_location,
      haveFrom ? { lat: fLat, lng: fLng } : null,
      haveTo ? { lat: tLat, lng: tLng } : null,
    );
  }
});

const deleteUnionRoute = asyncHandler(async (req, res) => {
  const { routeId } = req.params;

  const resUnion = await pool.query(
    `SELECT ua.union_id
     FROM union_admins ua
     JOIN unions u ON u.id = ua.union_id
     WHERE ua.user_id = $1 AND u.status = 'approved'
     LIMIT 1`,
    [req.user.id]
  );
  if (resUnion.rows.length === 0) {
    throw ApiError.forbidden('No approved union found for this admin');
  }

  const unionId = resUnion.rows[0].union_id;

  const result = await pool.query(
    'DELETE FROM union_routes WHERE id = $1 AND union_id = $2 RETURNING id',
    [routeId, unionId]
  );

  if (result.rowCount === 0) {
    throw ApiError.notFound('Route not found in your union');
  }

  logger.info(`Union route removed: ${routeId} from union ${unionId} by admin ${req.user.id}`);

  ApiResponse.success(null, 'Route removed').send(res);
});

module.exports = {
  getUnionRoutes,
  addUnionRoute,
  deleteUnionRoute,
};
