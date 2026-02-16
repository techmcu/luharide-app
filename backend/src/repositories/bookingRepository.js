/**
 * Repository: booking read for rating flow
 * Single query for booking + trip (driver_id) – avoids N+1 and keeps controller thin
 */
const { pool } = require('../config/database');

async function getBookingWithTripForRating(bookingId) {
  const result = await pool.query(
    `SELECT b.id, b.passenger_id, b.status, b.confirmed_at, t.driver_id
     FROM bookings b
     JOIN trips t ON b.trip_id = t.id
     WHERE b.id = $1`,
    [bookingId]
  );
  return result.rows[0] || null;
}

module.exports = {
  getBookingWithTripForRating,
};
