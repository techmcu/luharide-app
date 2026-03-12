/**
 * Ride Cleanup Job
 *
 * Runs every night at midnight (IST = UTC+5:30 → 18:30 UTC).
 * Also runs once on server startup to catch any missed window.
 *
 * What it does:
 *   1. union_schedules  → HARD DELETE rides whose departure day has passed.
 *      Safe: union_schedules have no booking records attached.
 *      Keeps today's rides intact until midnight.
 *
 *   2. trips (driver rides) → SOFT DELETE: mark status = 'completed'.
 *      Never hard-delete trips — booking records reference trip_id.
 *      Marking completed keeps booking history intact while hiding the
 *      ride from all passenger searches (which filter status='scheduled').
 *
 * Why not hard-delete trips?
 *   Bookings → trips FK cascade would wipe passengers' booking history.
 *   Drivers lose their earnings/rating records.
 *   Audit trail disappears.
 *   All real ride-sharing apps (BlaBlaCar, Ola, Uber) use soft-delete / status=completed.
 */

const cron = require('node-cron');
const { pool } = require('../config/database');
const logger = require('../config/logger');

async function runCleanup() {
  const label = '[RideCleanup]';
  try {
    // ── 1. Union schedules: hard delete past rides ──────────────────────────
    // departure_time < CURRENT_DATE means anything before today 00:00 UTC.
    // Rides from today stay until the next midnight tick.
    const unionDel = await pool.query(
      `DELETE FROM union_schedules
       WHERE departure_time < CURRENT_DATE::timestamp
       RETURNING id`
    );
    if (unionDel.rowCount > 0) {
      logger.info(`${label} Deleted ${unionDel.rowCount} expired union_schedule(s)`);
    }

    // ── 2. Driver trips: soft complete past scheduled rides ─────────────────
    // Any trip that was still 'scheduled' but its departure time has already
    // passed by more than 1 hour is automatically marked 'completed'.
    // The 1-hour grace window allows drivers who started late to still show as active.
    const tripsDone = await pool.query(
      `UPDATE trips
       SET status = 'completed', updated_at = NOW()
       WHERE status = 'scheduled'
         AND departure_time < NOW() - INTERVAL '1 hour'
       RETURNING id`
    );
    if (tripsDone.rowCount > 0) {
      logger.info(`${label} Auto-completed ${tripsDone.rowCount} expired trip(s)`);
    }

    if (unionDel.rowCount === 0 && tripsDone.rowCount === 0) {
      logger.info(`${label} Nothing to clean up`);
    }
  } catch (err) {
    // 42P01 = relation does not exist (migrations not run yet) — skip silently
    if (err.code === '42P01') return;
    logger.warn(`${label} Error during cleanup: ${err.message}`);
  }
}

function start() {
  // Run once immediately on server start to catch any missed cleanup window
  runCleanup();

  // Schedule: every day at midnight IST (18:30 UTC) and also at 00:30 UTC as fallback
  // '30 18 * * *' = 18:30 UTC = 00:00 IST
  cron.schedule('30 18 * * *', () => {
    logger.info('[RideCleanup] Midnight IST cleanup triggered');
    runCleanup();
  });

  // Also run at 00:30 UTC (06:00 IST) as a safety net
  cron.schedule('30 0 * * *', () => {
    logger.info('[RideCleanup] 06:00 IST safety cleanup triggered');
    runCleanup();
  });

  logger.info('[RideCleanup] Job scheduled (midnight IST + 06:00 IST daily)');
}

module.exports = { start, runCleanup };
