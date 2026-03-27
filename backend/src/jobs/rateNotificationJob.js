const { pool } = require('../config/database');
const logger = require('../config/logger');
const { emitNotificationToUser } = require('../socket/realtimeEmitter');
const {
  withPgAdvisoryTryLock,
  JOB_NS,
  JOB_RATE_NOTIFICATIONS,
} = require('./pgAdvisoryTryLock');

const INTERVAL_MS = 60 * 1000; // 1 minute

async function sendAndDelete(client, row) {
  const dataJson = JSON.stringify({ booking_id: row.booking_id });
  const r = await client.query(
    `INSERT INTO notifications (user_id, type, title, body, data)
     VALUES ($1, 'rate_ride', 'Rate your driver', 'How was your ride? Tap to rate your driver.', $2::jsonb),
            ($3, 'rate_ride', 'Rate your passenger', 'How was the trip? Tap to rate your passenger.', $2::jsonb)
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
  }
}

function start() {
  run().catch((err) => logger.warn('Rate notification job error:', err.message));
  setInterval(() => {
    run().catch((e) => logger.warn('Rate notification job error:', e.message));
  }, INTERVAL_MS);
  logger.info(
    'Rate notification job started (independent trips: scheduled departure + 4h; others: after confirm/accept; runs every 1 min; PG advisory lock)'
  );
}

module.exports = { start, run };
