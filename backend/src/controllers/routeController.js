const { queryRead } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');

const searchRoutes = asyncHandler(async (req, res) => {
  const q = (req.query.q || '').trim().toLowerCase();
  const from = (req.query.from || '').trim().toLowerCase();
  const to = (req.query.to || '').trim().toLowerCase();

  const conditions = ['is_active = true'];
  const params = [];

  if (q) {
    params.push(`%${q}%`);
    const idx = params.length;
    conditions.push(
      `(LOWER(name) LIKE $${idx} OR LOWER(from_location) LIKE $${idx} OR LOWER(to_location) LIKE $${idx})`
    );
  }
  if (from) {
    params.push(`%${from}%`);
    conditions.push(`LOWER(from_location) LIKE $${params.length}`);
  }
  if (to) {
    params.push(`%${to}%`);
    conditions.push(`LOWER(to_location) LIKE $${params.length}`);
  }

  const where = conditions.join(' AND ');
  const result = await queryRead(
    `SELECT id, name, from_location, to_location, from_lat, from_lng,
            to_lat, to_lng, distance_km, estimated_duration_minutes,
            base_fare, is_popular
     FROM routes
     WHERE ${where}
     ORDER BY is_popular DESC, name ASC
     LIMIT 50`,
    params
  );

  ApiResponse.success(result.rows, 'Routes found').send(res);
});

const getPopularRoutes = asyncHandler(async (req, res) => {
  const result = await queryRead(
    `SELECT id, name, from_location, to_location, from_lat, from_lng,
            to_lat, to_lng, distance_km, estimated_duration_minutes,
            base_fare
     FROM routes
     WHERE is_active = true AND is_popular = true
     ORDER BY name ASC
     LIMIT 30`
  );

  ApiResponse.success(result.rows, 'Popular routes').send(res);
});

module.exports = {
  searchRoutes,
  getPopularRoutes,
};
