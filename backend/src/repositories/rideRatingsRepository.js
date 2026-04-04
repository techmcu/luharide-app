/**
 * Repository: data access for ride_ratings only
 * System design: separation of concerns – DB logic here, business logic in service
 * Scalability: indexed queries (rated_user_id, booking_id), pagination via LIMIT/OFFSET
 */
const { pool } = require('../config/database');
const logger = require('../config/logger');
const { offset } = require('../constants/pagination');

const TABLE = 'ride_ratings';

async function ensureTable() {
  const check = await pool.query(
    `SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = $1`,
    [TABLE]
  );
  if (check.rows.length > 0) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS ride_ratings (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
      from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      rated_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      from_role VARCHAR(20) NOT NULL CHECK (from_role IN ('passenger', 'driver')),
      rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
      comment TEXT,
      trip_context TEXT,
      created_at TIMESTAMP DEFAULT NOW(),
      UNIQUE(booking_id, from_role)
    );
    CREATE INDEX IF NOT EXISTS idx_ride_ratings_rated_user ON ride_ratings(rated_user_id);
    CREATE INDEX IF NOT EXISTS idx_ride_ratings_booking ON ride_ratings(booking_id);
  `);
  logger.info('ride_ratings table created (auto)');
}

async function findByBookingAndRole(bookingId, fromRole) {
  const result = await pool.query(
    'SELECT id FROM ride_ratings WHERE booking_id = $1 AND from_role = $2',
    [bookingId, fromRole]
  );
  return result.rows[0] || null;
}

async function create({
  bookingId,
  fromUserId,
  ratedUserId,
  fromRole,
  rating,
  comment,
  tripContext,
}) {
  try {
    await pool.query(
      `INSERT INTO ride_ratings (booking_id, from_user_id, rated_user_id, from_role, rating, comment, trip_context)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [bookingId, fromUserId, ratedUserId, fromRole, rating, comment, tripContext || null]
    );
  } catch (e) {
    if (e.code === '42703') {
      await pool.query(
        `INSERT INTO ride_ratings (booking_id, from_user_id, rated_user_id, from_role, rating, comment)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [bookingId, fromUserId, ratedUserId, fromRole, rating, comment]
      );
      return;
    }
    throw e;
  }
}

async function countByRatedUserId(ratedUserId) {
  const result = await pool.query(
    'SELECT COUNT(*)::int AS total FROM ride_ratings WHERE rated_user_id = $1',
    [ratedUserId]
  );
  return parseInt(result.rows[0]?.total || 0, 10);
}

async function listByRatedUserId(ratedUserId, page, limit) {
  const off = offset(page, limit);
  let result;
  try {
    result = await pool.query(
      `SELECT r.id, r.rating, r.comment, r.created_at, r.from_role, r.trip_context, u.name AS from_name
       FROM ride_ratings r
       JOIN users u ON u.id = r.from_user_id
       WHERE r.rated_user_id = $1
       ORDER BY r.created_at DESC
       LIMIT $2 OFFSET $3`,
      [ratedUserId, limit, off]
    );
  } catch (e) {
    if (e.code !== '42703') throw e;
    result = await pool.query(
      `SELECT r.id, r.rating, r.comment, r.created_at, r.from_role, u.name AS from_name
       FROM ride_ratings r
       JOIN users u ON u.id = r.from_user_id
       WHERE r.rated_user_id = $1
       ORDER BY r.created_at DESC
       LIMIT $2 OFFSET $3`,
      [ratedUserId, limit, off]
    );
  }
  return result.rows.map((row) => ({
    id: row.id,
    rating: row.rating,
    comment: row.comment || '',
    created_at: row.created_at,
    from_name: row.from_name || 'User',
    from_role: row.from_role,
    trip_context: row.trip_context || null,
  }));
}

async function getSummaryByUserId(userId) {
  const result = await pool.query(
    `SELECT COUNT(*)::int AS total_ratings, COALESCE(AVG(rating), 0)::decimal(3,2) AS average_rating
     FROM ride_ratings WHERE rated_user_id = $1`,
    [userId]
  );
  const row = result.rows[0];
  return {
    total_ratings: parseInt(row?.total_ratings || 0, 10),
    average_rating: parseFloat(row?.average_rating || 0),
  };
}

module.exports = {
  ensureTable,
  findByBookingAndRole,
  create,
  countByRatedUserId,
  listByRatedUserId,
  getSummaryByUserId,
};
