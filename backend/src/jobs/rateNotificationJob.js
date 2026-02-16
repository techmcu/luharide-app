const { pool } = require('../config/database');
const logger = require('../config/logger');

const INTERVAL_MS = 60 * 1000; // 1 minute

function run() {
  pool.query(
    `SELECT id, booking_id, passenger_id, driver_id
     FROM pending_rate_notifications
     WHERE send_after <= NOW()`
  ).then((result) => {
    if (result.rows.length === 0) return;
    return Promise.all(result.rows.map((row) => sendAndDelete(row)));
  }).catch((err) => {
    if (err.code === '42P01') {
      // relation "pending_rate_notifications" does not exist
      return;
    }
    logger.warn('Rate notification job error:', err.message);
  });
}

function sendAndDelete(row) {
  const dataJson = JSON.stringify({ booking_id: row.booking_id });
  return pool.query(
    `INSERT INTO notifications (user_id, type, title, body, data)
     VALUES ($1, 'rate_ride', 'Rate your driver', 'Your ride was accepted. Rate your driver.', $2::jsonb),
            ($3, 'rate_ride', 'Rate your passenger', 'You accepted a booking. Rate your passenger.', $2::jsonb)`,
    [row.passenger_id, dataJson, row.driver_id]
  ).then(() => pool.query('DELETE FROM pending_rate_notifications WHERE id = $1', [row.id]))
    .catch((err) => logger.warn('Rate notification send/delete failed:', err.message));
}

function start() {
  run();
  setInterval(run, INTERVAL_MS);
  logger.info('Rate notification job started (every 1 min)');
}

module.exports = { start, run };
