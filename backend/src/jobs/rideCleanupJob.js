/**
 * Ride Cleanup Job — Tiered Data Retention Policy
 *
 * Industry standard approach (BlaBlaCar / Ola style):
 *
 *  Stage 1 — union_schedules (union rides, no bookings):
 *    DELETE immediately after departure day passes (midnight).
 *    Safe: no booking records reference union_schedules.
 *
 *  Stage 2 — trips: auto-complete past scheduled rides:
 *    UPDATE status='completed' for trips whose departure passed > 1 hour ago.
 *    1-hour grace: driver who started late still shows as active.
 *    Completed trips hidden from passenger search (filter: status='scheduled').
 *
 *  Stage 3 — trips: hard purge after 90-day retention window:
 *    DELETE completed/cancelled trips older than 90 days.
 *    Cascades: bookings → ride_ratings → pending_rate_notifications all deleted.
 *    Why 90 days?
 *      - Covers disputes and refund windows.
 *      - Driver history still visible for 3 months.
 *      - 1000+ rides won't accumulate forever.
 *      - Standard: Ola keeps 90 days, Uber keeps 6 months.
 *
 * Schedule: runs at midnight IST (18:30 UTC) + 06:00 IST safety net.
 * Also runs once on server startup to process any missed window.
 */

const cron = require('node-cron');
const { pool } = require('../config/database');
const logger = require('../config/logger');

// How long to keep completed/cancelled trip records (bookings cascade-delete with them)
const TRIP_RETENTION_DAYS = 60;

async function runCleanup() {
  const label = '[RideCleanup]';
  let totalDeleted = 0;
  let totalCompleted = 0;
  let totalPurged = 0;

  try {
    // ── Stage 1: union_schedules — delete past rides ────────────────────────
    const unionDel = await pool.query(
      `DELETE FROM union_schedules
       WHERE departure_time < CURRENT_DATE::timestamp
       RETURNING id`
    );
    totalDeleted = unionDel.rowCount;

    // ── Stage 2: trips — auto-complete overdue scheduled rides ──────────────
    const tripsDone = await pool.query(
      `UPDATE trips
       SET status = 'completed', updated_at = NOW()
       WHERE status = 'scheduled'
         AND departure_time < NOW() - INTERVAL '1 hour'
       RETURNING id`
    );
    totalCompleted = tripsDone.rowCount;

    // ── Stage 3: trips — hard purge after 90-day retention ──────────────────
    // Only deletes completed or cancelled trips — never 'scheduled' or 'in_progress'.
    // ON DELETE CASCADE in schema handles: bookings, ride_ratings,
    // pending_rate_notifications automatically.
    const tripsPurge = await pool.query(
      `DELETE FROM trips
       WHERE status IN ('completed', 'cancelled')
         AND departure_time < NOW() - INTERVAL '${TRIP_RETENTION_DAYS} days'
       RETURNING id`
    );
    totalPurged = tripsPurge.rowCount;

    // Log summary
    const parts = [];
    if (totalDeleted > 0)   parts.push(`deleted ${totalDeleted} union ride(s)`);
    if (totalCompleted > 0) parts.push(`completed ${totalCompleted} trip(s)`);
    if (totalPurged > 0)    parts.push(`purged ${totalPurged} old trip(s) (>${TRIP_RETENTION_DAYS}d)`);

    if (parts.length > 0) {
      logger.info(`${label} ${parts.join(', ')}`);
    } else {
      logger.info(`${label} Nothing to clean up`);
    }

  } catch (err) {
    if (err.code === '42P01') return; // migrations not run yet
    logger.warn(`${label} Error: ${err.message}`);
  }
}

function start() {
  // Run once at startup to catch any missed window
  runCleanup();

  // Midnight IST = 18:30 UTC
  cron.schedule('30 18 * * *', () => {
    logger.info('[RideCleanup] Midnight IST cleanup triggered');
    runCleanup();
  });

  // 06:00 IST = 00:30 UTC — safety net
  cron.schedule('30 0 * * *', () => {
    logger.info('[RideCleanup] 06:00 IST safety cleanup triggered');
    runCleanup();
  });

  logger.info(`[RideCleanup] Scheduled — midnight IST daily. Trip retention: ${TRIP_RETENTION_DAYS} days`);
}

module.exports = { start, runCleanup };
