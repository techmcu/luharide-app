/**
 * Evening batch maintenance (~midnight IST = 18:30 UTC).
 *
 * - Every table with data growth has retention or FIFO cap here.
 * - Passenger search hides past departures immediately (tripController + retentionConfig grace).
 * - ride_ratings are NOT deleted (booking_id SET NULL via migration); trust/reviews kept forever.
 * - Startup: refresh_tokens cleanup only (no heavy purge on every deploy).
 */

const cron = require('node-cron');
const { pool } = require('../config/database');
const logger = require('../config/logger');
const rc = require('../config/retentionConfig');
const {
  withPgAdvisoryTryLock,
  JOB_NS,
  JOB_RIDE_CLEANUP,
} = require('./pgAdvisoryTryLock');
const { cleanupExpiredTokens } = require('../services/tokenService');
const { cleanupExpiredOTPs } = require('../services/otpService');
const { sendTelegramAlert, formatJobAlert } = require('../utils/telegramAlert');
const { isRedisEnabled, checkRedisMemory, flushExpiredKeys } = require('../config/redis');

function logPurge(label, name, count) {
  if (count > 0) logger.info(`${label} purged ${count} ${name}`);
}

async function runEveningMaintenance() {
  const label = '[Cleanup]';

  try {
    const ran = await withPgAdvisoryTryLock(pool, JOB_NS, JOB_RIDE_CLEANUP, async (client) => {

      // ── Union schedules: age + FIFO ──
      const u1 = await client.query(
        `DELETE FROM union_schedules
         WHERE departure_time < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.unionScheduleRetentionDays]
      );
      logPurge(label, 'union_schedules (age)', u1.rowCount);

      const u2 = await client.query(
        `WITH past AS (
           SELECT id, union_id,
             ROW_NUMBER() OVER (PARTITION BY union_id ORDER BY departure_time DESC) AS rn
           FROM union_schedules
           WHERE departure_time < NOW()
         )
         DELETE FROM union_schedules s USING past p
         WHERE s.id = p.id AND p.rn > $1`,
        [rc.unionScheduleMaxPerUnion]
      );
      logPurge(label, 'union_schedules (fifo)', u2.rowCount);

      // ── Pending bookings: auto-expire stale + restore available_seats + notify passenger ──
      const pendingExpiry = await client.query(
        `WITH expired AS (
           UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
             cancellation_reason = 'auto-expired'
           WHERE status = 'pending'
             AND created_at < NOW() - ($1::int * INTERVAL '1 hour')
           RETURNING id, trip_id, passenger_id, seat_numbers
         )
         SELECT id, trip_id, passenger_id, seat_numbers FROM expired`,
        [rc.pendingBookingExpiryHours]
      );
      const seatsByTrip = {};
      for (const row of pendingExpiry.rows) {
        const seats = Array.isArray(row.seat_numbers) ? row.seat_numbers.length : 0;
        seatsByTrip[row.trip_id] = (seatsByTrip[row.trip_id] || 0) + seats;
      }
      for (const [tripId, seats] of Object.entries(seatsByTrip)) {
        if (seats > 0) {
          await client.query(
            'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
            [seats, tripId]
          );
        }
      }
      for (const row of pendingExpiry.rows) {
        try {
          await client.query(
            `INSERT INTO notifications (user_id, type, title, body, data)
             VALUES ($1, 'booking_auto_cancelled',
               'Booking expired',
               'The driver did not respond in time. Your booking was auto-cancelled. Please try another ride.',
               $2::jsonb)`,
            [row.passenger_id, JSON.stringify({ booking_id: row.id, trip_id: row.trip_id })]
          );
        } catch (e) {
          logger.warn(`${label} expired booking notification failed: ${e.message}`);
        }
      }
      if (pendingExpiry.rows.length > 0) {
        logPurge(label, `pending bookings auto-expired (${Object.values(seatsByTrip).reduce((a, b) => a + b, 0)} seats restored)`, pendingExpiry.rows.length);
      }

      // ── Union trips: auto-complete stale scheduled (independent handled by tripLifecycleJob) ──
      const tc = await client.query(
        `UPDATE trips SET status = 'completed', updated_at = NOW()
         WHERE status IN ('scheduled', 'in_progress')
           AND COALESCE(created_source, '') != 'independent_driver'
           AND COALESCE(arrival_time, departure_time + INTERVAL '2 hours') <= NOW()
         RETURNING id`
      );
      for (const row of tc.rows) {
        await client.query(
          `UPDATE bookings SET status = 'completed' WHERE trip_id = $1 AND status = 'confirmed'`,
          [row.id]
        );
        await client.query(
          `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
             cancellation_reason = 'auto-expired-trip-completed'
           WHERE trip_id = $1 AND status = 'pending'`,
          [row.id]
        );
      }
      logPurge(label, 'union trips auto-completed', tc.rowCount);

      // ── Dependent data: purge BEFORE trips (FK references without CASCADE) ──

      // ── Location history (GPS): age ──
      const loc = await client.query(
        `DELETE FROM location_history
         WHERE recorded_at < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.locationHistoryRetentionDays]
      );
      logPurge(label, 'location_history', loc.rowCount);

      // ── SOS logs: age ──
      const sos = await client.query(
        `DELETE FROM sos_logs
         WHERE created_at < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.sosLogRetentionDays]
      );
      logPurge(label, 'sos_logs', sos.rowCount);

      // ── Login history: age ──
      const lh = await client.query(
        `DELETE FROM login_history
         WHERE created_at < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.loginHistoryRetentionDays]
      );
      logPurge(label, 'login_history', lh.rowCount);

      // ── Trips: age-based purge (completed/cancelled only) ──
      const tp = await client.query(
        `DELETE FROM trips t
         WHERE t.status IN ('completed', 'cancelled')
           AND (
             (COALESCE(t.created_source, '') <> 'union_admin'
               AND t.departure_time < NOW() - ($1::int * INTERVAL '1 day'))
             OR (t.created_source = 'union_admin'
               AND t.departure_time < NOW() - ($2::int * INTERVAL '1 day'))
           )`,
        [rc.tripRetentionDaysIndependent, rc.tripRetentionDaysUnion]
      );
      logPurge(label, 'trips (age)', tp.rowCount);

      // ── Trips: FIFO per driver ──
      const tf = await client.query(
        `WITH ranked AS (
           SELECT id,
             ROW_NUMBER() OVER (
               PARTITION BY driver_id
               ORDER BY departure_time DESC NULLS LAST, created_at DESC NULLS LAST
             ) AS rn
           FROM trips WHERE status IN ('completed', 'cancelled')
         )
         DELETE FROM trips t USING ranked r
         WHERE t.id = r.id AND r.rn > $1`,
        [rc.tripHistoryMaxPerDriver]
      );
      logPurge(label, 'trips (fifo)', tf.rowCount);

      // ── Recent routes: FIFO per user ──
      const rr = await client.query(
        `WITH ranked AS (
           SELECT id, user_id,
             ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
           FROM recent_routes
         )
         DELETE FROM recent_routes USING ranked r
         WHERE recent_routes.id = r.id AND r.rn > $1`,
        [rc.recentRoutesMaxPerUser]
      );
      logPurge(label, 'recent_routes (fifo)', rr.rowCount);

      // ── Pending rate notifications: stale ──
      const prn = await client.query(
        `DELETE FROM pending_rate_notifications
         WHERE created_at < NOW() - ($1::int * INTERVAL '1 hour')`,
        [rc.pendingRateNotificationRetentionHours]
      );
      logPurge(label, 'pending_rate_notifications', prn.rowCount);

      // ── Contact logs: age ──
      const cl = await client.query(
        `DELETE FROM contact_logs
         WHERE created_at < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.contactLogRetentionDays]
      );
      logPurge(label, 'contact_logs', cl.rowCount);

      // ── Payments: age ──
      const pay = await client.query(
        `DELETE FROM payments
         WHERE created_at < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.paymentRetentionDays]
      );
      logPurge(label, 'payments', pay.rowCount);

      // ── Complaints: resolved + old ──
      const cmp = await client.query(
        `DELETE FROM complaints
         WHERE status = 'resolved'
           AND COALESCE(resolved_at, created_at) < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.complaintResolvedRetentionDays]
      );
      logPurge(label, 'complaints (resolved)', cmp.rowCount);

      // ── Driver verification requests: completed/rejected + old ──
      const dvr = await client.query(
        `DELETE FROM driver_verification_requests
         WHERE status IN ('approved', 'rejected')
           AND updated_at < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.driverVerificationCompletedRetentionDays]
      );
      logPurge(label, 'driver_verification_requests', dvr.rowCount);

      // ── Driver documents (legacy): age ──
      const dd = await client.query(
        `DELETE FROM driver_documents
         WHERE uploaded_at < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.driverDocumentRetentionDays]
      );
      logPurge(label, 'driver_documents (legacy)', dd.rowCount);

      // ── Reviews (legacy table): age ──
      const rev = await client.query(
        `DELETE FROM reviews
         WHERE created_at < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.legacyReviewRetentionDays]
      );
      logPurge(label, 'reviews (legacy)', rev.rowCount);

      // ── Broadcasts: FIFO cap ──
      const br = await client.query(
        `WITH ranked AS (
           SELECT id, ROW_NUMBER() OVER (ORDER BY created_at DESC) AS rn
           FROM broadcasts
         )
         DELETE FROM broadcasts USING ranked r
         WHERE broadcasts.id = r.id AND r.rn > $1`,
        [rc.broadcastMaxTotal]
      );
      logPurge(label, 'broadcasts (fifo)', br.rowCount);

      // ── Ride ratings: FIFO per user ──
      const rat = await client.query(
        `DELETE FROM ride_ratings WHERE id IN (
           SELECT r.id FROM ride_ratings r
           INNER JOIN (
             SELECT rated_user_id,
               (array_agg(id ORDER BY created_at DESC))[$1:] AS old_ids
             FROM ride_ratings GROUP BY rated_user_id HAVING count(*) > $2
           ) excess ON r.id = ANY(excess.old_ids)
         )`,
        [rc.reviewsMaxPerUser + 1, rc.reviewsMaxPerUser]
      );
      logPurge(label, 'ride_ratings (fifo)', rat.rowCount);

      // ── Union daily actions: age ──
      const uda = await client.query(
        `DELETE FROM union_daily_actions
         WHERE created_at < NOW() - ($1::int * INTERVAL '1 day')`,
        [rc.unionDailyActionsRetentionDays]
      );
      logPurge(label, 'union_daily_actions', uda.rowCount);
    });

    if (ran === false) {
      logger.debug(`${label} skipped — another instance holds lock`);
    } else {
      logger.info(`${label} evening maintenance complete`);
    }
  } catch (err) {
    if (err.code !== '42P01') {
      logger.warn(`${label} Error: ${err.message}`);
      sendTelegramAlert(formatJobAlert('Evening Cleanup', err.message, err.stack));
    }
  }

  // ── VACUUM ANALYZE high-churn tables (non-blocking, reclaims dead tuples) ──
  try {
    const vacuumTables = [
      'trips', 'bookings', 'notifications', 'location_history',
      'login_history', 'pending_rate_notifications', 'union_daily_actions',
    ];
    for (const tbl of vacuumTables) {
      try {
        await pool.query(`VACUUM ANALYZE ${tbl}`);
      } catch (e) {
        if (e.code !== '42P01') logger.warn(`${label} VACUUM ${tbl} failed: ${e.message}`);
      }
    }
    logger.info(`${label} VACUUM ANALYZE complete`);
  } catch (e) {
    logger.warn(`${label} VACUUM failed: ${e.message}`);
  }

  // ── Refresh tokens (outside advisory lock — lightweight) ──
  try {
    await cleanupExpiredTokens();
  } catch (e) {
    logger.warn(`${label} refresh_tokens cleanup failed: ${e.message}`);
  }

  // ── OTP verifications cleanup ──
  try {
    await cleanupExpiredOTPs();
  } catch (e) {
    logger.warn(`${label} OTP cleanup failed: ${e.message}`);
  }

  // ── Notifications + FCM tokens (outside advisory lock — pool queries) ──
  try {
    const notifDel = await pool.query(
      `DELETE FROM notifications
       WHERE (is_read = TRUE AND created_at < (NOW() - $1::int * INTERVAL '1 hour'))
          OR created_at < (NOW() - $2::int * INTERVAL '1 hour')`,
      [rc.notificationReadRetentionHours, rc.notificationUnreadRetentionHours]
    );
    logPurge(label, 'notifications', notifDel.rowCount);

    const fcmDel = await pool.query(
      `DELETE FROM fcm_tokens WHERE updated_at < (NOW() - $1::int * INTERVAL '1 day')`,
      [rc.fcmTokenRetentionDays]
    );
    logPurge(label, 'fcm_tokens', fcmDel.rowCount);
  } catch (e) {
    logger.warn(`${label} notification/FCM cleanup failed: ${e.message}`);
  }

  // ── Redis health check (memory + stale keys) ──
  if (isRedisEnabled()) {
    try {
      const mem = await checkRedisMemory();
      if (mem) logger.info(`${label} Redis memory: ${(mem.used / 1024 / 1024).toFixed(1)}MB, maxmemory-policy: ${mem.policy}`);
      const keys = await flushExpiredKeys();
      if (keys > 0) logger.info(`${label} Redis key count: ${keys}`);
    } catch (e) {
      logger.warn(`${label} Redis health check failed: ${e.message}`);
    }
  }
}

async function runStartupTokenCleanupOnly() {
  try {
    await cleanupExpiredTokens();
  } catch (e) {
    logger.warn('[Cleanup] startup refresh_tokens cleanup failed:', e.message);
  }
}

function start() {
  runStartupTokenCleanupOnly().catch((e) => logger.warn('[Cleanup] startup token cleanup failed:', e.message));

  cron.schedule('30 18 * * *', () => {
    logger.info('[Cleanup] Evening IST maintenance starting');
    runEveningMaintenance().catch((e) => {
      logger.error('[Cleanup] evening maintenance failed:', e.message);
      sendTelegramAlert(formatJobAlert('Evening Cleanup', e.message, e.stack));
    });
  });

  logger.info(
    `[Cleanup] Evening batch 18:30 UTC. Retention: trips ${rc.tripRetentionDaysIndependent}d/${rc.tripRetentionDaysUnion}d, login ${rc.loginHistoryRetentionDays}d, GPS ${rc.locationHistoryRetentionDays}d, payments ${rc.paymentRetentionDays}d, contacts ${rc.contactLogRetentionDays}d.`
  );
}

module.exports = { start, runCleanup: runEveningMaintenance, runEveningMaintenance };
