/**
 * Retention & storage limits for all entities.
 * Keeps VPS clean — every table has a cap or TTL.
 * Env overrides optional.
 */

function intEnv(name, fallback, min, max) {
  const v = parseInt(process.env[name], 10);
  if (!Number.isFinite(v)) return fallback;
  return Math.min(max, Math.max(min, v));
}

module.exports = {
  // --- Trips ---
  tripSearchGraceMinutesAfterDeparture: intEnv('TRIP_SEARCH_GRACE_MINUTES_AFTER_DEPARTURE', 0, 0, 180),
  tripRetentionDaysIndependent: intEnv('TRIP_RETENTION_DAYS_INDEPENDENT', 7, 1, 90),
  tripRetentionDaysUnion: intEnv('TRIP_RETENTION_DAYS_UNION', 15, 1, 90),
  tripHistoryMaxPerDriver: intEnv('TRIP_HISTORY_MAX_PER_DRIVER', 100, 10, 500),
  tripAutoCompleteAfterDepartureHours: intEnv('TRIP_AUTO_COMPLETE_AFTER_DEPARTURE_HOURS', 1, 0, 48),

  // --- Union schedules ---
  unionScheduleRetentionDays: intEnv('UNION_SCHEDULE_RETENTION_DAYS', 15, 1, 90),
  unionScheduleMaxPerUnion: intEnv('UNION_SCHEDULE_MAX_PER_UNION', 100, 10, 500),

  // --- Notifications (user) ---
  notificationReadRetentionHours: 12,
  notificationUnreadRetentionHours: 24,

  // --- FCM tokens ---
  fcmTokenRetentionDays: 30,

  // --- Reviews ---
  reviewsMaxPerUser: intEnv('REVIEWS_MAX_PER_USER', 500, 50, 5000),

  // --- Admin broadcasts (permanent, display capped) ---
  broadcastDisplayLimit: 10,
};
