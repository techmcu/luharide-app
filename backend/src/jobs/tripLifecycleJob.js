const { pool } = require('../config/database');
const logger = require('../config/logger');
const rc = require('../config/retentionConfig');
const { sendTelegramAlert, formatJobAlert } = require('../utils/telegramAlert');
const { emitNotificationToUser, emitTripUpdated } = require('../socket/realtimeEmitter');
const {
  withPgAdvisoryTryLock,
  JOB_NS,
  JOB_TRIP_LIFECYCLE,
} = require('./pgAdvisoryTryLock');

const INTERVAL_MS =
  Number(process.env.TRIP_LIFECYCLE_JOB_INTERVAL_MS) > 0
    ? Number(process.env.TRIP_LIFECYCLE_JOB_INTERVAL_MS)
    : 2 * 60 * 1000;

async function run() {
  try {
    await withPgAdvisoryTryLock(pool, JOB_NS, JOB_TRIP_LIFECYCLE, async (client) => {

      // ── Auto-start: scheduled → in_progress when departure_time arrives (independent driver only) ──
      const startResult = await client.query(
        `UPDATE trips SET status = 'in_progress', updated_at = NOW()
         WHERE status = 'scheduled'
           AND created_source = 'independent_driver'
           AND departure_time <= NOW()
         RETURNING id, driver_id`
      );

      for (const trip of startResult.rows) {
        const pending = await client.query(
          `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
             cancellation_reason = 'auto-expired-trip-started'
           WHERE trip_id = $1 AND status = 'pending'
           RETURNING id, passenger_id, seat_numbers`,
          [trip.id]
        );

        let restoredSeats = 0;
        for (const row of pending.rows) {
          restoredSeats += Array.isArray(row.seat_numbers) ? row.seat_numbers.length : 0;
        }
        if (restoredSeats > 0) {
          await client.query(
            'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
            [restoredSeats, trip.id]
          );
        }

        for (const row of pending.rows) {
          try {
            const n = await client.query(
              `INSERT INTO notifications (user_id, type, title, body, data)
               VALUES ($1, 'booking_auto_cancelled',
                 'Booking not confirmed',
                 'The driver did not confirm your booking. The ride has started. Please try another ride.',
                 $2::jsonb)
               RETURNING id, user_id, type, title, body, data, created_at, is_read`,
              [row.passenger_id, JSON.stringify({ booking_id: row.id, trip_id: trip.id })]
            );
            if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
          } catch (_) {}
        }

        try {
          const dn = await client.query(
            `INSERT INTO notifications (user_id, type, title, body, data)
             VALUES ($1, 'trip_auto_started',
               'Your ride has started!',
               'Your scheduled ride has auto-started as departure time has arrived. Have a safe ride!',
               $2::jsonb)
             RETURNING id, user_id, type, title, body, data, created_at, is_read`,
            [trip.driver_id, JSON.stringify({ trip_id: trip.id })]
          );
          if (dn.rows[0]) emitNotificationToUser(dn.rows[0].user_id, dn.rows[0]);
        } catch (_) {}

        emitTripUpdated(trip.id, { status: 'in_progress', reason: 'auto_started' });
      }

      if (startResult.rowCount > 0) {
        logger.info(`[TripLifecycle] Auto-started ${startResult.rowCount} trip(s)`);
      }

      // ── Auto-finish: in_progress → completed when arrival_time passes (independent driver only) ──
      // Uses arrival_time (estimated end) — not a fixed offset from departure.
      // No notification to driver — silent transition.
      const finishResult = await client.query(
        `UPDATE trips SET status = 'completed', updated_at = NOW()
         WHERE status = 'in_progress'
           AND created_source = 'independent_driver'
           AND COALESCE(arrival_time, departure_time + INTERVAL '2 hours') <= NOW()
         RETURNING id`
      );

      for (const trip of finishResult.rows) {
        const completed = await client.query(
          `UPDATE bookings SET status = 'completed'
           WHERE trip_id = $1 AND status = 'confirmed'
           RETURNING id, passenger_id`,
          [trip.id]
        );

        for (const row of completed.rows) {
          try {
            const n = await client.query(
              `INSERT INTO notifications (user_id, type, title, body, data)
               VALUES ($1, 'trip_completed',
                 'Happy Journey!',
                 'We hope you had a great travel experience with LuhaRide!',
                 $2::jsonb)
               RETURNING id, user_id, type, title, body, data, created_at, is_read`,
              [row.passenger_id, JSON.stringify({ booking_id: row.id, trip_id: trip.id })]
            );
            if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
          } catch (_) {}
        }

        const pendingLeft = await client.query(
          `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
             cancellation_reason = 'auto-expired-trip-completed'
           WHERE trip_id = $1 AND status = 'pending'
           RETURNING seat_numbers`,
          [trip.id]
        );
        let seats = 0;
        for (const r of pendingLeft.rows) {
          seats += Array.isArray(r.seat_numbers) ? r.seat_numbers.length : 0;
        }
        if (seats > 0) {
          await client.query(
            'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
            [seats, trip.id]
          );
        }

        emitTripUpdated(trip.id, { status: 'completed', reason: 'auto_finished' });
      }

      if (finishResult.rowCount > 0) {
        logger.info(`[TripLifecycle] Auto-finished ${finishResult.rowCount} trip(s)`);
      }
    });
  } catch (err) {
    if (err.code === '42P01') return;
    logger.warn('[TripLifecycle] error:', err.message);
    sendTelegramAlert(formatJobAlert('Trip Lifecycle', err.message, err.stack));
  }
}

let _timer = null;

function start() {
  run().catch((e) => logger.warn('[TripLifecycle] startup error:', e.message));
  _timer = setInterval(() => {
    run().catch((e) => logger.warn('[TripLifecycle] error:', e.message));
  }, INTERVAL_MS);
  logger.info(
    `[TripLifecycle] started (scan every ${Math.round(INTERVAL_MS / 1000)}s). Auto-complete after ${rc.tripAutoCompleteAfterDepartureHours}h past departure.`
  );
}

function stop() {
  if (_timer) { clearInterval(_timer); _timer = null; }
}

module.exports = { start, stop, run };
