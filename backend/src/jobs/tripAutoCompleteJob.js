const { pool } = require('../config/database');
const logger = require('../config/logger');
const { sendTelegramAlert, formatJobAlert } = require('../utils/telegramAlert');
const { emitTripUpdated, emitNotificationToUser } = require('../socket/realtimeEmitter');
const {
  withPgAdvisoryTryLock,
  JOB_NS,
  JOB_TRIP_AUTO_COMPLETE,
} = require('./pgAdvisoryTryLock');

const INTERVAL_MS =
  Number(process.env.TRIP_AUTO_COMPLETE_JOB_INTERVAL_MS) > 0
    ? Number(process.env.TRIP_AUTO_COMPLETE_JOB_INTERVAL_MS)
    : 30 * 60 * 1000;

async function run() {
  try {
    await withPgAdvisoryTryLock(pool, JOB_NS, JOB_TRIP_AUTO_COMPLETE, async (client) => {
      const result = await client.query(
        `UPDATE trips SET status = 'completed', updated_at = NOW()
         WHERE status IN ('scheduled', 'in_progress')
           AND created_source = 'independent_driver'
           AND COALESCE(arrival_time, departure_time + INTERVAL '2 hours') <= NOW()
         RETURNING id`
      );

      if (result.rows.length === 0) return;

      for (const row of result.rows) {
        const completed = await client.query(
          `UPDATE bookings SET status = 'completed'
           WHERE trip_id = $1 AND status = 'confirmed'
           RETURNING id, passenger_id`,
          [row.id]
        );

        for (const bk of completed.rows) {
          try {
            const n = await client.query(
              `INSERT INTO notifications (user_id, type, title, body, data)
               VALUES ($1, 'trip_completed',
                 'Happy Journey!',
                 'We hope you had a great travel experience with LuhaRide!',
                 $2::jsonb)
               RETURNING id, user_id, type, title, body, data, created_at, is_read`,
              [bk.passenger_id, JSON.stringify({ booking_id: bk.id, trip_id: row.id })]
            );
            if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
          } catch (_) {}
        }

        await client.query(
          `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
             cancellation_reason = 'auto-expired-trip-completed'
           WHERE trip_id = $1 AND status = 'pending'`,
          [row.id]
        );
        emitTripUpdated(row.id, { status: 'completed', reason: 'auto_completed' });
      }
      logger.info(`[TripAutoComplete] Auto-completed ${result.rows.length} independent driver trip(s)`);
    });
  } catch (err) {
    if (err.code === '42P01') return;
    logger.warn('[TripAutoComplete] error:', err.message);
    sendTelegramAlert(formatJobAlert('Trip Auto-Complete', err.message, err.stack));
  }
}

function start() {
  run().catch((e) => logger.warn('Trip auto-complete job error:', e.message));
  setInterval(() => {
    run().catch((e) => logger.warn('Trip auto-complete job error:', e.message));
  }, INTERVAL_MS);
  logger.info(
    `Trip auto-complete job started (scan every ${Math.round(INTERVAL_MS / 1000)}s). Override: TRIP_AUTO_COMPLETE_JOB_INTERVAL_MS`
  );
}

module.exports = { start, run };
