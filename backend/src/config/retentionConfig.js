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
  unionScheduleRetentionDays: intEnv('UNION_SCHEDULE_RETENTION_DAYS', 30, 1, 90),
  unionScheduleMaxPerUnion: intEnv('UNION_SCHEDULE_MAX_PER_UNION', 200, 10, 500),

  // --- Notifications (user) ---
  notificationReadRetentionHours: intEnv('NOTIFICATION_READ_RETENTION_HOURS', 48, 6, 720),
  notificationUnreadRetentionHours: intEnv('NOTIFICATION_UNREAD_RETENTION_HOURS', 168, 24, 720),

  // --- FCM tokens ---
  fcmTokenRetentionDays: 30,

  // --- Reviews ---
  reviewsMaxPerUser: intEnv('REVIEWS_MAX_PER_USER', 500, 50, 5000),

  // --- Admin broadcasts (permanent, display capped) ---
  broadcastDisplayLimit: 10,
  broadcastMaxTotal: intEnv('BROADCAST_MAX_TOTAL', 100, 20, 1000),

  // --- Login history ---
  loginHistoryRetentionDays: intEnv('LOGIN_HISTORY_RETENTION_DAYS', 90, 7, 365),

  // --- Location history (GPS tracking) ---
  locationHistoryRetentionDays: intEnv('LOCATION_HISTORY_RETENTION_DAYS', 7, 1, 30),

  // --- SOS logs ---
  sosLogRetentionDays: intEnv('SOS_LOG_RETENTION_DAYS', 90, 30, 365),

  // --- Recent routes (passenger search history) ---
  recentRoutesMaxPerUser: intEnv('RECENT_ROUTES_MAX_PER_USER', 20, 5, 50),

  // --- Pending bookings (auto-expire so seats aren't blocked forever) ---
  pendingBookingExpiryHours: intEnv('PENDING_BOOKING_EXPIRY_HOURS', 24, 1, 72),

  // --- Pending rate notifications ---
  pendingRateNotificationRetentionHours: 48,

  // --- Contact logs (union driver calls/WhatsApp) ---
  contactLogRetentionDays: intEnv('CONTACT_LOG_RETENTION_DAYS', 30, 7, 90),

  // --- Payments ---
  paymentRetentionDays: intEnv('PAYMENT_RETENTION_DAYS', 365, 90, 1825),

  // --- Complaints ---
  complaintResolvedRetentionDays: intEnv('COMPLAINT_RESOLVED_RETENTION_DAYS', 90, 30, 365),

  // --- Driver verification requests ---
  driverVerificationCompletedRetentionDays: intEnv('DRIVER_VERIFICATION_COMPLETED_RETENTION_DAYS', 90, 30, 365),

  // --- Driver documents (legacy) ---
  driverDocumentRetentionDays: intEnv('DRIVER_DOCUMENT_RETENTION_DAYS', 180, 30, 365),

  // --- Reviews (legacy table) ---
  legacyReviewRetentionDays: intEnv('LEGACY_REVIEW_RETENTION_DAYS', 90, 30, 365),

  // --- Emergency contacts ---
  emergencyContactsMaxPerUser: intEnv('EMERGENCY_CONTACTS_MAX_PER_USER', 10, 3, 20),

  // --- Union daily actions (rate-limit tracking) ---
  unionDailyActionsRetentionDays: intEnv('UNION_DAILY_ACTIONS_RETENTION_DAYS', 7, 1, 30),
};
