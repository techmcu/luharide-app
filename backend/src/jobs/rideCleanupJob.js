/**
 * Ride / union schedule retention — single evening batch (~midnight IST = 18:30 UTC).
 *
 * - Passenger search hides past departures immediately (tripController + retentionConfig grace).
 * - This job: auto-complete stale scheduled trips, purge old completed/cancelled trips,
 *   trim per-driver FIFO cap, union_schedules age + FIFO cap.
 * - ride_ratings are NOT deleted (booking_id SET NULL via migration); trust/reviews kept forever.
 *
 * Startup: refresh_tokens cleanup only (no trip purge) to avoid load on every deploy.
 */

const cron = require('node-cron');
const { pool } = require('../config/database');
const logger = require('../config/logger');
const retentionConfig = require('../config/retentionConfig');
const {
  withPgAdvisoryTryLock,
  JOB_NS,
  JOB_RIDE_CLEANUP,
} = require('./pgAdvisoryTryLock');
const { cleanupExpiredTokens } = require('../services/tokenService');

async function runEveningMaintenance() {
  const label = '[RideCleanup]';
  const rc = retentionConfig;
  let unionAge = 0;
  let unionFifo = 0;
  let tripsCompleted = 0;
  let tripsAge = 0;
  let tripsFifo = 0;

  try {
    const ran = await withPgAdvisoryTryLock(pool, JOB_NS, JOB_RIDE_CLEANUP, async (client) => {
      const u1 = await client.query(
        `DELETE FROM union_schedules
         WHERE departure_time < NOW() - ($1::int * INTERVAL '1 day')
         RETURNING id`,
        [rc.unionScheduleRetentionDays]
      );
      unionAge = u1.rowCount;

      const u2 = await client.query(
        `WITH past AS (
           SELECT id, union_id,
             ROW_NUMBER() OVER (PARTITION BY union_id ORDER BY departure_time DESC) AS rn
           FROM union_schedules
           WHERE departure_time < NOW()
         )
         DELETE FROM union_schedules s
         USING past p
         WHERE s.id = p.id AND p.rn > $1
         RETURNING s.id`,
        [rc.unionScheduleMaxPerUnion]
      );
      unionFifo = u2.rowCount;

      const completeH = rc.tripAutoCompleteAfterDepartureHours;
      const td = await client.query(
        `UPDATE trips
         SET status = 'completed', updated_at = NOW()
         WHERE status = 'scheduled'
           AND departure_time < NOW() - ($1::int * INTERVAL '1 hour')
         RETURNING id`,
        [completeH]
      );
      tripsCompleted = td.rowCount;

      const tp = await client.query(
        `DELETE FROM trips t
         WHERE t.status IN ('completed', 'cancelled')
           AND (
             (COALESCE(t.created_source, '') <> 'union_admin'
               AND t.departure_time < NOW() - ($1::int * INTERVAL '1 day'))
             OR (t.created_source = 'union_admin'
               AND t.departure_time < NOW() - ($2::int * INTERVAL '1 day'))
           )
         RETURNING t.id`,
        [rc.tripRetentionDaysIndependent, rc.tripRetentionDaysUnion]
      );
      tripsAge = tp.rowCount;

      const tf = await client.query(
        `WITH ranked AS (
           SELECT id,
             ROW_NUMBER() OVER (
               PARTITION BY driver_id
               ORDER BY departure_time DESC NULLS LAST, created_at DESC NULLS LAST
             ) AS rn
           FROM trips
           WHERE status IN ('completed', 'cancelled')
         )
         DELETE FROM trips t
         USING ranked r
         WHERE t.id = r.id AND r.rn > $1
         RETURNING t.id`,
        [rc.tripHistoryMaxPerDriver]
      );
      tripsFifo = tf.rowCount;
    });

    if (ran === false) {
      logger.debug(`${label} skipped — another instance holds cleanup lock`);
    } else {
      const parts = [];
      if (unionAge > 0) parts.push(`union_schedules age ${unionAge}`);
      if (unionFifo > 0) parts.push(`union_schedules fifo ${unionFifo}`);
      if (tripsCompleted > 0) parts.push(`auto-completed ${tripsCompleted} trip(s)`);
      if (tripsAge > 0) parts.push(`purged ${tripsAge} trip(s) by retention`);
      if (tripsFifo > 0) parts.push(`fifo-trimmed ${tripsFifo} trip(s)`);
      if (parts.length > 0) {
        logger.info(`${label} ${parts.join(', ')}`);
      } else {
        logger.info(`${label} Nothing to clean up`);
      }
    }
  } catch (err) {
    if (err.code !== '42P01') {
      logger.warn(`${label} Error: ${err.message}`);
    }
  }

  try {
    await cleanupExpiredTokens();
  } catch (e) {
    logger.warn(`${label} refresh_tokens cleanup failed: ${e.message}`);
  }

  // Notification, FCM token, review hygiene
  try {
    const notifDel = await pool.query(
      `DELETE FROM notifications
       WHERE (is_read = TRUE AND created_at < (NOW() - INTERVAL '${rc.notificationReadRetentionHours} hours'))
          OR created_at < (NOW() - INTERVAL '${rc.notificationUnreadRetentionHours} hours')`
    );
    if (notifDel.rowCount > 0) logger.info(`${label} purged ${notifDel.rowCount} expired notification(s)`);

    const fcmDel = await pool.query(
      `DELETE FROM fcm_tokens WHERE updated_at < (NOW() - INTERVAL '${rc.fcmTokenRetentionDays} days')`
    );
    if (fcmDel.rowCount > 0) logger.info(`${label} purged ${fcmDel.rowCount} stale FCM token(s)`);

    const revDel = await pool.query(
      `DELETE FROM ride_ratings WHERE id IN (
         SELECT r.id FROM ride_ratings r
         INNER JOIN (
           SELECT rated_user_id, (array_agg(id ORDER BY created_at DESC))[${rc.reviewsMaxPerUser + 1}:] AS old_ids
           FROM ride_ratings GROUP BY rated_user_id HAVING count(*) > ${rc.reviewsMaxPerUser}
         ) excess ON r.id = ANY(excess.old_ids)
       )`
    );
    if (revDel.rowCount > 0) logger.info(`${label} capped ${revDel.rowCount} review(s) over ${rc.reviewsMaxPerUser}/user`);
  } catch (e) {
    logger.warn(`${label} notification/FCM/review cleanup failed: ${e.message}`);
  }
}

async function runStartupTokenCleanupOnly() {
  try {
    await cleanupExpiredTokens();
  } catch (e) {
    logger.warn('[RideCleanup] startup refresh_tokens cleanup failed:', e.message);
  }
}

function start() {
  runStartupTokenCleanupOnly();

  cron.schedule('30 18 * * *', () => {
    logger.info('[RideCleanup] Evening IST maintenance (trips, union_schedules, tokens)');
    runEveningMaintenance();
  });

  logger.info(
    `[RideCleanup] Evening batch 18:30 UTC (~midnight IST). Retention: independent ${retentionConfig.tripRetentionDaysIndependent}d / union ${retentionConfig.tripRetentionDaysUnion}d; driver fifo ${retentionConfig.tripHistoryMaxPerDriver}; union fifo ${retentionConfig.unionScheduleMaxPerUnion}. Startup: tokens only.`
  );
}

module.exports = { start, runCleanup: runEveningMaintenance, runEveningMaintenance };
