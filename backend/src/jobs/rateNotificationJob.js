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
    'SELECT status FROM bookings WHERE id = $1',
    [row.booking_id]
  );
  if (booking.rows.length === 0 || booking.rows[0].status !== 'confirmed') {
    await client.query('DELETE FROM pending_rate_notifications WHERE id = $1', [row.id]);
    return;
  }

  const dataJson = JSON.stringify({ booking_id: row.booking_id });
  const r = await client.query(
    `INSERT INTO notifications (user_id, type, title, body, data)
     VALUES ($1, 'rate_ride', 'How was your ride?', 'Aaj ki ride kaisi rahi? Apne driver ko rate karein.', $2::jsonb),
            ($3, 'rate_ride', 'Rate your passenger', 'Aaj ki ride kaisi rahi? Apne passenger ko rate karein.', $2::jsonb)
     RETURNING id, user_id, type, title, body, data, created_at, is_read`,
    [row.passenger_id, dataJson, row.driver_id]
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

function start() {
  run().catch((err) => logger.warn('Rate notification job error:', err.message));
  setInterval(() => {
    run().catch((e) => logger.warn('Rate notification job error:', e.message));
  }, INTERVAL_MS);
  logger.info(
    `Rate notification job started (scan every ${Math.round(INTERVAL_MS / 1000)}s; PG advisory lock). Override: RATE_NOTIFICATION_JOB_INTERVAL_MS`
  );
}

module.exports = { start, run };
