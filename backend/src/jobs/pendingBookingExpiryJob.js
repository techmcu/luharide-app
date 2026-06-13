const { pool } = require('../config/database');
const logger = require('../config/logger');
const { sendTelegramAlert, formatJobAlert } = require('../utils/telegramAlert');
const { emitNotificationToUser, emitTripUpdated } = require('../socket/realtimeEmitter');
const {
  withPgAdvisoryTryLock,
  JOB_NS,
  JOB_PENDING_BOOKING_EXPIRY,
} = require('./pgAdvisoryTryLock');

const INTERVAL_MS =
  Number(process.env.PENDING_BOOKING_EXPIRY_JOB_INTERVAL_MS) > 0
    ? Number(process.env.PENDING_BOOKING_EXPIRY_JOB_INTERVAL_MS)
    : 2 * 60 * 1000;

const CUTOFF_MINUTES = Number(process.env.PENDING_BOOKING_CUTOFF_MINUTES) > 0
  ? Number(process.env.PENDING_BOOKING_CUTOFF_MINUTES)
  : 1;

async function cancelPendingBookingsForTrips(client, expiredRows) {
  for (const row of expiredRows) {
    try {
      const dataJson = JSON.stringify({
        booking_id: row.booking_id,
        trip_id: row.trip_id,
      });
      const n = await client.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'booking_auto_cancelled',
           'Booking not confirmed',
           'Your booking was auto-cancelled because the driver did not respond before departure.',
           $2::jsonb)
         RETURNING id, user_id, type, title, body, data, created_at, is_read`,
        [row.passenger_id, dataJson]
      );
      if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
      emitTripUpdated(row.trip_id, { reason: 'pending_booking_auto_cancelled' });
    } catch (e) {
      logger.warn(`Pending booking expiry notification failed for booking ${row.booking_id}: ${e.message}`);
    }
  }
}

async function run() {
  try {
    await withPgAdvisoryTryLock(pool, JOB_NS, JOB_PENDING_BOOKING_EXPIRY, async (client) => {
      const result = await client.query(
        `WITH expired AS (
           UPDATE bookings b SET status = 'cancelled', cancelled_at = NOW(),
             cancellation_reason = 'auto-expired-before-departure'
           FROM trips t
           WHERE b.trip_id = t.id
             AND b.status = 'pending'
             AND t.departure_time <= NOW() + ($1::int * INTERVAL '1 minute')
           RETURNING b.id AS booking_id, b.trip_id, b.passenger_id, b.seat_numbers
         )
         SELECT booking_id, trip_id, passenger_id, seat_numbers FROM expired`,
        [CUTOFF_MINUTES]
      );

      if (result.rows.length === 0) return;

      const seatsByTrip = {};
      for (const row of result.rows) {
        const count = Array.isArray(row.seat_numbers) ? row.seat_numbers.length : 0;
        seatsByTrip[row.trip_id] = (seatsByTrip[row.trip_id] || 0) + count;
      }
      for (const [tripId, seats] of Object.entries(seatsByTrip)) {
        if (seats > 0) {
          await client.query(
            'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
            [seats, tripId]
          );
        }
      }

      logger.info(`[PendingExpiry] Auto-cancelled ${result.rows.length} pending bookings (${Object.keys(seatsByTrip).length} trips, cutoff ${CUTOFF_MINUTES}min)`);
      await cancelPendingBookingsForTrips(client, result.rows);
    });
  } catch (err) {
    if (err.code === '42P01') return;
    logger.warn('Pending booking expiry job error:', err.message);
    sendTelegramAlert(formatJobAlert('Pending Booking Expiry', err.message, err.stack));
  }
}

let _timer = null;

function start() {
  run().catch((e) => logger.warn('Pending booking expiry job error:', e.message));
  _timer = setInterval(() => {
    run().catch((e) => logger.warn('Pending booking expiry job error:', e.message));
  }, INTERVAL_MS);
  logger.info(
    `Pending booking expiry job started (scan every ${Math.round(INTERVAL_MS / 1000)}s, cutoff ${CUTOFF_MINUTES}min before departure)`
  );
}

function stop() {
  if (_timer) { clearInterval(_timer); _timer = null; }
}

module.exports = { start, stop, run };
