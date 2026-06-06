const { pool } = require('../config/database');
const logger = require('../config/logger');
const { sendTelegramAlert, formatJobAlert } = require('../utils/telegramAlert');
const { emitTripUpdated } = require('../socket/realtimeEmitter');
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
           AND departure_time <= NOW()
         RETURNING id`
      );

      if (result.rows.length === 0) return;

      logger.info(`[TripAutoComplete] Auto-completed ${result.rows.length} independent driver trip(s)`);
      for (const row of result.rows) {
        emitTripUpdated(row.id, { reason: 'auto_completed' });
      }
    });
  } catch (err) {
    if (err.code === '42P01') return;
    logger.warn('Trip auto-complete job error:', err.message);
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
