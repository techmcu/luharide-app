/**
 * Trip / schedule retention & search visibility. Env overrides optional.
 * Ratings (ride_ratings) are never deleted by cleanup — only trip/booking rows.
 */

function intEnv(name, fallback, min, max) {
  const v = parseInt(process.env[name], 10);
  if (!Number.isFinite(v)) return fallback;
  return Math.min(max, Math.max(min, v));
}

module.exports = {
  /** Hide from passenger search after departure + this many minutes (no cron needed). */
  tripSearchGraceMinutesAfterDeparture: intEnv(
    'TRIP_SEARCH_GRACE_MINUTES_AFTER_DEPARTURE',
    15,
    0,
    180
  ),

  /** Purge completed/cancelled trips for independent / legacy drivers (not union_admin). */
  tripRetentionDaysIndependent: intEnv('TRIP_RETENTION_DAYS_INDEPENDENT', 10, 1, 365),

  /** Purge completed/cancelled trips created by union flow. */
  tripRetentionDaysUnion: intEnv('TRIP_RETENTION_DAYS_UNION', 20, 1, 730),

  /** Max completed/cancelled trip rows kept per driver (FIFO by newest departure). */
  tripHistoryMaxPerDriver: intEnv('TRIP_HISTORY_MAX_PER_DRIVER', 200, 10, 5000),

  /** Past union_schedules rows older than this are eligible for delete. */
  unionScheduleRetentionDays: intEnv('UNION_SCHEDULE_RETENTION_DAYS', 20, 1, 730),

  /** Max past union_schedules rows per union (newest kept). */
  unionScheduleMaxPerUnion: intEnv('UNION_SCHEDULE_MAX_PER_UNION', 200, 10, 5000),

  /** Mark scheduled → completed when departure is older than this (evening job). */
  tripAutoCompleteAfterDepartureHours: intEnv(
    'TRIP_AUTO_COMPLETE_AFTER_DEPARTURE_HOURS',
    1,
    0,
    48
  ),
};
