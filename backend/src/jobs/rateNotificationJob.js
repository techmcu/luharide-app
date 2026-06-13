const { pool } = require('../config/database');
const logger = require('../config/logger');
const { sendTelegramAlert, formatJobAlert } = require('../utils/telegramAlert');
const { emitNotificationToUser } = require('../socket/realtimeEmitter');
const {
  withPgAdvisoryTryLock,
  JOB_NS,
  JOB_RATE_NOTIFICATIONS,
} = require('./pgAdvisoryTryLock');

/**
 * How often we scan `pending_rate_notifications` (due rows). Default 15 minutes to cut server/DB load;
 * notifications may arrive up to this late after `send_after`. Override ms via env, e.g. 600000 = 10 min.
 *
 * Non-polling options (if you outgrow this): Redis/Bull delayed jobs per booking; or pg_cron calling
 * a small SQL function; or INSERT trigger + LISTEN/NOTIFY (still need a worker to sleep until send_after).
 */
const INTERVAL_MS =
  Number(process.env.RATE_NOTIFICATION_JOB_INTERVAL_MS) > 0
    ? Number(process.env.RATE_NOTIFICATION_JOB_INTERVAL_MS)
    : 15 * 60 * 1000;

async function sendAndDelete(client, row) {
  const booking = await client.query(
    `SELECT b.status, b.seat_numbers,
            p.name AS passenger_name,
            d.name AS driver_name,
            t.from_location, t.to_location
     FROM bookings b
     LEFT JOIN users p ON b.passenger_id = p.id
     LEFT JOIN trips t ON b.trip_id = t.id
     LEFT JOIN users d ON t.driver_id = d.id
     WHERE b.id = $1`,
    [row.booking_id]
  );
  const bk = booking.rows[0];
  if (!bk || (bk.status !== 'confirmed' && bk.status !== 'completed')) {
    await client.query('DELETE FROM pending_rate_notifications WHERE id = $1', [row.id]);
    return;
  }

  const alreadySent = await client.query(
    `SELECT 1 FROM notifications WHERE type = 'rate_ride' AND data->>'booking_id' = $1 LIMIT 1`,
    [row.booking_id]
  );
  if (alreadySent.rows.length > 0) {
    await client.query('DELETE FROM pending_rate_notifications WHERE id = $1', [row.id]);
    return;
  }

  const seats = Array.isArray(bk.seat_numbers) ? bk.seat_numbers : [];
  const seatLabel = seats.length > 0 ? `Seat ${seats.join(', ')}` : '';
  const route = [bk.from_location, bk.to_location].filter(Boolean).join(' → ') || 'Ride';
  const pName = bk.passenger_name || 'Passenger';
  const dName = bk.driver_name || 'Driver';

  const passengerData = JSON.stringify({
    booking_id: row.booking_id,
    target_name: dName,
    trip_route: route,
  });
  const driverData = JSON.stringify({
    booking_id: row.booking_id,
    target_name: pName,
    seat_numbers: seats,
    trip_route: route,
  });

  const driverBody = seatLabel
    ? `Rate ${pName} (${seatLabel}) — ${route}`
    : `Rate ${pName} — ${route}`;

  const r = await client.query(
    `INSERT INTO notifications (user_id, type, title, body, data)
     VALUES ($1, 'rate_ride', 'Rate your driver', $3, $4::jsonb),
            ($2, 'rate_ride', 'Rate your passenger', $5, $6::jsonb)
     RETURNING id, user_id, type, title, body, data, created_at, is_read`,
    [row.passenger_id, row.driver_id,
     `Rate ${dName} — ${route}`, passengerData,
     driverBody, driverData]
  );
  for (const n of r.rows) emitNotificationToUser(n.user_id, n);
  await client.query('DELETE FROM pending_rate_notifications WHERE id = $1', [row.id]);
}

async function run() {
  try {
    await withPgAdvisoryTryLock(pool, JOB_NS, JOB_RATE_NOTIFICATIONS, async (client) => {
      const result = await client.query(
        `SELECT id, booking_id, passenger_id, driver_id
         FROM pending_rate_notifications
         WHERE send_after <= NOW()`
      );
      if (result.rows.length === 0) return;
      for (const row of result.rows) {
        try {
          await sendAndDelete(client, row);
        } catch (err) {
          logger.warn('Rate notification send/delete failed:', err.message);
        }
      }
    });
  } catch (err) {
    if (err.code === '42P01') {
      return;
    }
    logger.warn('Rate notification job error:', err.message);
    sendTelegramAlert(formatJobAlert('Rate Notifications', err.message, err.stack));
  }
}

let _timer = null;

function start() {
  run().catch((err) => logger.warn('Rate notification job error:', err.message));
  _timer = setInterval(() => {
    run().catch((e) => logger.warn('Rate notification job error:', e.message));
  }, INTERVAL_MS);
  logger.info(
    `Rate notification job started (scan every ${Math.round(INTERVAL_MS / 1000)}s; PG advisory lock). Override: RATE_NOTIFICATION_JOB_INTERVAL_MS`
  );
}

function stop() {
  if (_timer) { clearInterval(_timer); _timer = null; }
}

module.exports = { start, stop, run };
