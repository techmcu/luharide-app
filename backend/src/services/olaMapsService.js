/**
 * Ola Maps (Krutrim) service — location intelligence for LuhaRide.
 *
 * Design goals (shared across monolith + all microservices):
 *  - NEVER throw to the caller. Every network/parse failure degrades to a safe
 *    empty/null value so a maps hiccup can never crash a request or a service.
 *  - Cache aggressively (in-process TTL cache) to stay well inside the free
 *    tier and to keep responses fast. Autocomplete/geocode results are stable.
 *  - Single axios instance with a hard timeout so a slow upstream cannot pile
 *    up sockets / event-loop pressure on a small VPS.
 *
 * API key + base url come from env (src/config/env.js). If the key is absent,
 * `isEnabled()` is false and all calls short-circuit to safe fallbacks.
 *
 * Endpoints (api.olamaps.io):
 *   GET  /places/v1/autocomplete?input=&api_key=
 *   GET  /places/v1/geocode?address=&api_key=
 *   GET  /places/v1/reverse-geocode?latlng=lat,lng&api_key=
 *   POST /routing/v1/directions?origin=lat,lng&destination=lat,lng&api_key=
 *   GET  /routing/v1/distanceMatrix?origins=&destinations=&api_key=
 */
const axios = require('axios');
const { config } = require('../config/env');
const logger = require('../config/logger');

const { apiKey, baseUrl, timeoutMs, biasLat, biasLng, biasRadiusM } = config.olaMaps;

// ---- HTTP client -----------------------------------------------------------
const http = axios.create({
  baseURL: baseUrl,
  timeout: timeoutMs,
  // We handle non-2xx ourselves (return safe fallbacks), don't let axios throw
  // for 4xx so a single bad query never bubbles up as a 500.
  validateStatus: (s) => s >= 200 && s < 500,
});

function isEnabled() {
  return !!apiKey;
}

// ---- Tiny TTL cache (bounded) ---------------------------------------------
// Keeps memory flat under load: when we hit MAX_ENTRIES we drop the oldest.
// Per-process is fine — correctness never depends on the cache, it's only a
// cost/latency optimisation. Map preserves insertion order → O(1) eviction.
const MAX_ENTRIES = 2000;
const cache = new Map();

function cacheGet(key) {
  const hit = cache.get(key);
  if (!hit) return undefined;
  if (hit.exp < Date.now()) {
    cache.delete(key);
    return undefined;
  }
  return hit.val;
}

function cacheSet(key, val, ttlMs) {
  if (cache.size >= MAX_ENTRIES) {
    const oldest = cache.keys().next().value;
    if (oldest !== undefined) cache.delete(oldest);
  }
  cache.set(key, { val, exp: Date.now() + ttlMs });
}

const TTL = {
  autocomplete: 6 * 60 * 60 * 1000, // 6h — place names are stable
  geocode: 24 * 60 * 60 * 1000,     // 24h
  reverse: 24 * 60 * 60 * 1000,     // 24h
  route: 30 * 60 * 1000,            // 30m — distance is stable, duration drifts with traffic
};

// ---- Validation helpers ----------------------------------------------------
function isValidLatLng(lat, lng) {
  return (
    Number.isFinite(lat) && Number.isFinite(lng) &&
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
  );
}

function coordKey(lat, lng) {
  // 5 decimals ≈ 1.1m — plenty for caching, collapses jittery GPS reads.
  return `${lat.toFixed(5)},${lng.toFixed(5)}`;
}

/**
 * Haversine straight-line distance in kilometres.
 * Pure/local (no API call) — used to pre-filter candidate rides cheaply before
 * spending an Ola road-distance call on only the closest few.
 */
function haversineKm(lat1, lng1, lat2, lng2) {
  if (!isValidLatLng(lat1, lng1) || !isValidLatLng(lat2, lng2)) return Infinity;
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ---- Polyline + corridor geometry (pure, no API) ---------------------------

/**
 * Decode a Google/Ola encoded polyline string into [[lat,lng], ...].
 * Returns [] on any malformed input (never throws).
 */
function decodePolyline(str) {
  if (typeof str !== 'string' || !str) return [];
  const points = [];
  let index = 0, lat = 0, lng = 0;
  try {
    while (index < str.length) {
      let result = 0, shift = 0, b;
      do { b = str.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lat += (result & 1) ? ~(result >> 1) : (result >> 1);
      result = 0; shift = 0;
      do { b = str.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lng += (result & 1) ? ~(result >> 1) : (result >> 1);
      points.push([lat / 1e5, lng / 1e5]);
    }
  } catch (_) { return points; }
  return points;
}

/** Downsample a polyline to at most `max` points (keeps first/last). */
function downsamplePolyline(points, max = 80) {
  if (!Array.isArray(points) || points.length <= max) return points || [];
  const step = (points.length - 1) / (max - 1);
  const out = [];
  for (let i = 0; i < max; i++) out.push(points[Math.round(i * step)]);
  return out;
}

/** Axis-aligned bounding box of a polyline → {minLat,maxLat,minLng,maxLng}|null. */
function polylineBbox(points) {
  if (!Array.isArray(points) || points.length === 0) return null;
  let minLat = Infinity, maxLat = -Infinity, minLng = Infinity, maxLng = -Infinity;
  for (const p of points) {
    const la = Number(p[0]), ln = Number(p[1]);
    if (!Number.isFinite(la) || !Number.isFinite(ln)) continue;
    if (la < minLat) minLat = la; if (la > maxLat) maxLat = la;
    if (ln < minLng) minLng = ln; if (ln > maxLng) maxLng = ln;
  }
  if (minLat === Infinity) return null;
  return { minLat, maxLat, minLng, maxLng };
}

/**
 * Project a point onto a polyline.
 * @returns {{distKm:number, alongKm:number}} distKm = shortest distance to the
 *   line; alongKm = how far along the route the nearest point sits (used to
 *   enforce travel direction: origin's alongKm must be < destination's).
 *   Returns {distKm:Infinity,alongKm:0} for bad input.
 */
function projectOntoPolyline(lat, lng, points) {
  if (!isValidLatLng(lat, lng) || !Array.isArray(points) || points.length === 0) {
    return { distKm: Infinity, alongKm: 0 };
  }
  if (points.length === 1) {
    return { distKm: haversineKm(lat, lng, points[0][0], points[0][1]), alongKm: 0 };
  }
  let best = Infinity, bestAlong = 0, cum = 0;
  for (let i = 0; i < points.length - 1; i++) {
    const [aLat, aLng] = points[i];
    const [bLat, bLng] = points[i + 1];
    const segLen = haversineKm(aLat, aLng, bLat, bLng);
    // Distance from point to this segment, approximated via the closer of:
    // perpendicular projection (in local planar coords) clamped to the segment.
    const proj = _pointToSegmentKm(lat, lng, aLat, aLng, bLat, bLng);
    if (proj.distKm < best) {
      best = proj.distKm;
      bestAlong = cum + proj.tFraction * segLen;
    }
    cum += segLen;
  }
  return { distKm: best, alongKm: bestAlong };
}

/** Point→segment distance (km) + fraction t along the segment of the nearest point. */
function _pointToSegmentKm(plat, plng, alat, alng, blat, blng) {
  // Local equirectangular projection (km) around the point — fine for short segs.
  const latRef = (plat * Math.PI) / 180;
  const kx = 111.32 * Math.cos(latRef); // km per degree lng at this latitude
  const ky = 110.57;                     // km per degree lat
  const ax = alng * kx, ay = alat * ky;
  const bx = blng * kx, by = blat * ky;
  const px = plng * kx, py = plat * ky;
  const dx = bx - ax, dy = by - ay;
  const len2 = dx * dx + dy * dy;
  let t = len2 === 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / len2;
  t = Math.max(0, Math.min(1, t));
  const cx = ax + t * dx, cy = ay + t * dy;
  return { distKm: Math.hypot(px - cx, py - cy), tFraction: t };
}

// ---- Public API ------------------------------------------------------------

/**
 * Place autocomplete suggestions for a typed query.
 * @returns {Promise<Array<{description,placeId,lat,lng}>>} always an array.
 */
async function autocomplete(input) {
  const q = String(input || '').trim();
  if (!isEnabled() || q.length < 2) return [];

  const key = `ac:${q.toLowerCase()}`;
  const cached = cacheGet(key);
  if (cached) return cached;

  try {
    const res = await http.get('/places/v1/autocomplete', {
      // location/radius bias → same-named places in our region rank first.
      params: { input: q, api_key: apiKey, location: `${biasLat},${biasLng}`, radius: biasRadiusM },
    });
    if (res.status !== 200 || !res.data) return [];
    const predictions = Array.isArray(res.data.predictions) ? res.data.predictions : [];
    const out = predictions.map((p) => {
      const loc = p.geometry?.location || {};
      // Prefer the short main name (e.g. "Bigsi") over the long full address
      // ("Bigsi 1323, post office naugaon, p249171, ...") for a clean suggestion.
      const shortName = p.structured_formatting?.main_text || p.description || '';
      // Secondary = district/state context (e.g. "Uttarkashi, Uttarakhand") so the
      // user can tell apart same-named places (Barkot UP vs Barkot Uttarakhand).
      const secondary = p.structured_formatting?.secondary_text || '';
      return {
        description: shortName,
        secondary,
        fullText: p.description || shortName,
        placeId: p.place_id || null,
        lat: Number.isFinite(loc.lat) ? loc.lat : null,
        lng: Number.isFinite(loc.lng) ? loc.lng : null,
      };
    }).filter((p) => p.description);
    cacheSet(key, out, TTL.autocomplete);
    return out;
  } catch (err) {
    logger.warn(`[olaMaps] autocomplete failed: ${err.message}`);
    return [];
  }
}

/**
 * Forward geocode: address text → coordinates.
 * @returns {Promise<{lat,lng,formattedAddress}|null>}
 */
async function geocode(address) {
  const a = String(address || '').trim();
  if (!isEnabled() || a.length < 2) return null;

  const key = `geo:${a.toLowerCase()}`;
  const cached = cacheGet(key);
  if (cached !== undefined) return cached;

  try {
    const res = await http.get('/places/v1/geocode', {
      params: { address: a, api_key: apiKey },
    });
    const results = res.data?.geocodingResults || res.data?.results || [];
    const first = Array.isArray(results) ? results[0] : null;
    const loc = first?.geometry?.location;
    if (!loc || !isValidLatLng(loc.lat, loc.lng)) {
      cacheSet(key, null, TTL.geocode);
      return null;
    }
    const out = {
      lat: loc.lat,
      lng: loc.lng,
      formattedAddress: first.formatted_address || a,
    };
    cacheSet(key, out, TTL.geocode);
    return out;
  } catch (err) {
    logger.warn(`[olaMaps] geocode failed: ${err.message}`);
    return null;
  }
}

/**
 * Reverse geocode: coordinates → human-readable place name.
 * @returns {Promise<string|null>}
 */
async function reverseGeocode(lat, lng) {
  if (!isEnabled() || !isValidLatLng(lat, lng)) return null;

  const key = `rev:${coordKey(lat, lng)}`;
  const cached = cacheGet(key);
  if (cached !== undefined) return cached;

  try {
    const res = await http.get('/places/v1/reverse-geocode', {
      params: { latlng: `${lat},${lng}`, api_key: apiKey },
    });
    const results = res.data?.results || [];
    const name = Array.isArray(results) && results[0]?.formatted_address
      ? results[0].formatted_address
      : null;
    cacheSet(key, name, TTL.reverse);
    return name;
  } catch (err) {
    logger.warn(`[olaMaps] reverseGeocode failed: ${err.message}`);
    return null;
  }
}

/**
 * Road distance + duration + route polyline between two points (Directions API).
 * Falls back to a straight 2-point line if the API is disabled or fails, so
 * fare/corridor features always get *something* usable.
 * @returns {Promise<{distanceKm,durationMin,estimated,points,bbox}|null>}
 *   points = [[lat,lng],...] route line (downsampled); bbox = {minLat,...}.
 */
async function getRouteDistance(origin, destination) {
  if (!origin || !destination) return null;
  const { lat: oLat, lng: oLng } = origin;
  const { lat: dLat, lng: dLng } = destination;
  if (!isValidLatLng(oLat, oLng) || !isValidLatLng(dLat, dLng)) return null;

  const fallback = () => {
    const straight = haversineKm(oLat, oLng, dLat, dLng);
    if (!Number.isFinite(straight)) return null;
    // Hill roads wind ~1.4x the straight line; ~28 km/h avg in Uttarakhand terrain.
    const distanceKm = +(straight * 1.4).toFixed(1);
    const points = [[oLat, oLng], [dLat, dLng]];
    return {
      distanceKm,
      durationMin: Math.round((distanceKm / 28) * 60),
      estimated: true,
      points,
      bbox: polylineBbox(points),
    };
  };

  if (!isEnabled()) return fallback();

  const key = `rt:${coordKey(oLat, oLng)}>${coordKey(dLat, dLng)}`;
  const cached = cacheGet(key);
  if (cached !== undefined) return cached;

  try {
    const res = await http.post('/routing/v1/directions', null, {
      params: {
        origin: `${oLat},${oLng}`,
        destination: `${dLat},${dLng}`,
        api_key: apiKey,
      },
    });
    const route = res.data?.routes?.[0];
    const leg = route?.legs?.[0];
    const meters = leg?.distance ?? route?.distance;
    const seconds = leg?.duration ?? route?.duration;
    if (!Number.isFinite(meters) || meters <= 0) {
      const fb = fallback();
      cacheSet(key, fb, TTL.route);
      return fb;
    }
    // Route geometry: Ola returns an encoded polyline (Google algorithm).
    const encoded = route?.overview_polyline?.points || route?.overview_polyline || route?.geometry;
    let points = downsamplePolyline(decodePolyline(typeof encoded === 'string' ? encoded : ''));
    if (!points || points.length < 2) points = [[oLat, oLng], [dLat, dLng]]; // safety
    const out = {
      distanceKm: +(meters / 1000).toFixed(1),
      durationMin: Number.isFinite(seconds) ? Math.round(seconds / 60) : null,
      estimated: false,
      points,
      bbox: polylineBbox(points),
    };
    cacheSet(key, out, TTL.route);
    return out;
  } catch (err) {
    logger.warn(`[olaMaps] getRouteDistance failed: ${err.message}`);
    return fallback();
  }
}

module.exports = {
  isEnabled,
  autocomplete,
  geocode,
  reverseGeocode,
  getRouteDistance,
  haversineKm,
  isValidLatLng,
  // corridor geometry (pure helpers)
  decodePolyline,
  downsamplePolyline,
  polylineBbox,
  projectOntoPolyline,
};
