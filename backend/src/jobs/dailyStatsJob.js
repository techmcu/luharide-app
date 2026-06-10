const cron = require('node-cron');
const { pool } = require('../config/database');
const logger = require('../config/logger');
const { sendTelegramAlert, formatJobAlert } = require('../utils/telegramAlert');
const { withPgAdvisoryTryLock, JOB_NS, JOB_DAILY_STATS } = require('./pgAdvisoryTryLock');
const RETENTION_DAYS = 180;

async function aggregateYesterday() {
  const label = '[DailyStats]';

  try {
    const ran = await withPgAdvisoryTryLock(pool, JOB_NS, JOB_DAILY_STATS, async (client) => {
      const yesterday = `(CURRENT_DATE - INTERVAL '1 day')`;

      await client.query(`
        INSERT INTO daily_stats (
          stat_date, new_users, new_trips, completed_trips, cancelled_trips,
          new_bookings, confirmed_bookings, cancelled_bookings, upcoming_trips, active_drivers
        )
        SELECT
          ${yesterday}::date AS stat_date,
          (SELECT COUNT(*)::int FROM users WHERE created_at::date = ${yesterday}::date),
          (SELECT COUNT(*)::int FROM trips WHERE created_at::date = ${yesterday}::date),
          (SELECT COUNT(*)::int FROM trips WHERE status = 'completed' AND updated_at::date = ${yesterday}::date),
          (SELECT COUNT(*)::int FROM trips WHERE status = 'cancelled' AND updated_at::date = ${yesterday}::date),
          (SELECT COUNT(*)::int FROM bookings WHERE created_at::date = ${yesterday}::date),
          (SELECT COUNT(*)::int FROM bookings WHERE status = 'confirmed' AND created_at::date = ${yesterday}::date),
          (SELECT COUNT(*)::int FROM bookings WHERE status = 'cancelled' AND cancelled_at::date = ${yesterday}::date AND COALESCE(cancellation_reason, '') NOT LIKE 'auto-expired%'),
          (SELECT COUNT(*)::int FROM trips WHERE status = 'scheduled' AND departure_time::date > ${yesterday}::date AND created_at::date <= ${yesterday}::date),
          (SELECT COUNT(DISTINCT driver_id)::int FROM trips WHERE created_at::date = ${yesterday}::date)
        ON CONFLICT (stat_date) DO UPDATE SET
          new_users = EXCLUDED.new_users,
          new_trips = EXCLUDED.new_trips,
          completed_trips = EXCLUDED.completed_trips,
          cancelled_trips = EXCLUDED.cancelled_trips,
          new_bookings = EXCLUDED.new_bookings,
          confirmed_bookings = EXCLUDED.confirmed_bookings,
          cancelled_bookings = EXCLUDED.cancelled_bookings,
          upcoming_trips = EXCLUDED.upcoming_trips,
          active_drivers = EXCLUDED.active_drivers
      `);

      const del = await client.query(
        `DELETE FROM daily_stats WHERE stat_date < CURRENT_DATE - make_interval(days => $1)`,
        [RETENTION_DAYS]
      );

      if (del.rowCount > 0) {
        logger.info(`${label} pruned ${del.rowCount} rows older than ${RETENTION_DAYS} days`);
      }

      logger.info(`${label} aggregated stats for yesterday`);
    });

    if (!ran) {
      logger.debug('[DailyStats] skipped — another instance holds the lock');
    }
  } catch (err) {
    if (err.code === '42P01') {
      logger.debug('[DailyStats] daily_stats table not found — run migration 053');
      return;
    }
    logger.error('[DailyStats] failed:', err.message);
    sendTelegramAlert(formatJobAlert('Daily Stats', err.message, err.stack));
  }
}

function start() {
  cron.schedule('35 18 * * *', () => {
    logger.info('[DailyStats] daily aggregation starting');
    aggregateYesterday().catch((e) => {
      logger.error('[DailyStats] aggregation failed:', e.message);
      sendTelegramAlert(formatJobAlert('Daily Stats', e.message, e.stack));
    });
  });

  logger.info(`[DailyStats] scheduled 18:35 UTC (00:05 IST). Retention: ${RETENTION_DAYS} days.`);
}

module.exports = { start, aggregateYesterday };
