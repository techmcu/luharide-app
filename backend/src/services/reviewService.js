/**
 * Service: review/rating business logic
 * OOP: single responsibility – validation, role resolution, orchestration
 * No DB details here; uses repositories
 */
const ApiError = require('../utils/ApiError');
const { RATING, RATING_COMMENT_MAX_WORDS, ROLES } = require('../constants/validation');
const { REVIEWS_WINDOW_MAX } = require('../constants/pagination');
const rideRatingsRepository = require('../repositories/rideRatingsRepository');
const bookingRepository = require('../repositories/bookingRepository');
const { pool } = require('../config/database');
const { emitNotificationToUser } = require('../socket/realtimeEmitter');
const logger = require('../config/logger');

function buildTripContext(booking) {
  const from = (booking.from_location || '').trim();
  const to = (booking.to_location || '').trim();
  const route = from && to ? `${from} → ${to}` : (from || to || 'Ride');
  if (!booking.departure_time) return route;
  const d = new Date(booking.departure_time);
  if (Number.isNaN(d.getTime())) return route;
  const stamp = `${d.toISOString().slice(0, 16).replace('T', ' ')} UTC`;
  return `${route} · ${stamp}`;
}

function trimCommentToMaxWords(comment, maxWords = RATING_COMMENT_MAX_WORDS) {
  if (!comment || typeof comment !== 'string') return '';
  const trimmed = comment.trim();
  const words = trimmed.split(/\s+/).filter(Boolean);
  if (words.length <= maxWords) return trimmed;
  return words.slice(0, maxWords).join(' ');
}

/**
 * Submit a rating for a booking. Resolves from_role and rated_user_id from booking.
 * @returns {Promise<{ message: string }>}
 */
async function submitRating(bookingId, userId, { rating, comment }) {
  if (!Number.isInteger(rating) || rating < RATING.MIN || rating > RATING.MAX) {
    throw ApiError.badRequest(`rating must be ${RATING.MIN} to ${RATING.MAX}`);
  }
  const rawComment = comment != null ? String(comment).trim() : '';
  const words = rawComment.split(/\s+/).filter(Boolean);
  if (words.length > RATING_COMMENT_MAX_WORDS) {
    throw ApiError.badRequest(`Comment cannot exceed ${RATING_COMMENT_MAX_WORDS} words`);
  }
  const safeComment = trimCommentToMaxWords(rawComment) || null;

  const booking = await bookingRepository.getBookingWithTripForRating(bookingId);
  if (!booking) throw ApiError.notFound('Booking not found');

  const wasCancelled = booking.status === 'cancelled';
  if (!['confirmed', 'completed'].includes(booking.status) && !wasCancelled) {
    throw ApiError.badRequest('Can only rate completed or cancelled bookings');
  }

  let fromRole;
  let ratedUserId;
  if (booking.passenger_id === userId) {
    fromRole = ROLES.PASSENGER;
    ratedUserId = booking.driver_id;
  } else if (booking.driver_id === userId) {
    fromRole = ROLES.DRIVER;
    ratedUserId = booking.passenger_id;
  } else {
    throw ApiError.forbidden('You can only rate your own booking');
  }

  if (wasCancelled) {
    const reason = (booking.cancellation_reason || '');
    const cancelledByDriver = reason.includes('Driver cancelled');
    const cancelledByAdmin = reason.toLowerCase().includes('platform admin');
    const cancelledByPassenger = !cancelledByDriver && !cancelledByAdmin && booking.cancellation_reason && !reason.startsWith('auto-');
    if (cancelledByAdmin) {
      throw ApiError.badRequest('Admin-cancelled bookings cannot be rated.');
    }
    if (cancelledByDriver && fromRole === ROLES.DRIVER) {
      throw ApiError.badRequest('You cancelled the ride — you cannot rate.');
    }
    if (cancelledByPassenger && fromRole === ROLES.PASSENGER) {
      throw ApiError.badRequest('You cancelled the booking — you cannot rate.');
    }
    if (!cancelledByDriver && !cancelledByPassenger) {
      throw ApiError.badRequest('Auto-cancelled bookings cannot be rated.');
    }
  }

  await rideRatingsRepository.ensureTable();
  const existing = await rideRatingsRepository.findByBookingAndRole(bookingId, fromRole);
  if (existing) {
    const isAutoRating = (existing.comment || '').startsWith('Auto-rating:');
    if (!isAutoRating) {
      throw ApiError.badRequest('You have already rated for this ride');
    }
    await pool.query(
      `UPDATE ride_ratings SET rating = $1, comment = $2, trip_context = $3
       WHERE id = $4`,
      [rating, safeComment, buildTripContext(booking), existing.id]
    );
  } else {
    await rideRatingsRepository.create({
      bookingId,
      fromUserId: userId,
      ratedUserId,
      fromRole,
      rating,
      comment: safeComment,
      tripContext: buildTripContext(booking),
    });
  }

  try {
    const roleLabel = fromRole === ROLES.PASSENGER ? 'passenger' : 'driver';
    const n = await pool.query(
      `INSERT INTO notifications (user_id, type, title, body, data)
       VALUES ($1, 'review_received', 'New review received', $2, $3::jsonb)
       RETURNING id, user_id, type, title, body, data, created_at, is_read`,
      [
        ratedUserId,
        `Your ${roleLabel} rated you ${rating} star${rating > 1 ? 's' : ''}.`,
        JSON.stringify({ booking_id: bookingId, rating }),
      ]
    );
    if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
  } catch (_) {}

  // Rating ≤ 2 with comment = auto-report (complaint)
  if (rating <= 2 && safeComment) {
    try {
      const monthKey = new Date().toISOString().slice(0, 7);
      await pool.query(
        `INSERT INTO driver_abuse_flags (user_id, flag_type, reason, month_window, violation_count)
         VALUES ($1, 'low_rating_report', $2, $3, $4)`,
        [
          ratedUserId,
          `${rating}-star rating with comment: "${safeComment.slice(0, 100)}" (booking: ${bookingId})`,
          monthKey,
          rating,
        ]
      );
    } catch (e) {
      if (e.code !== '42P01') logger.warn('Low rating report insert failed:', e.message);
    }
  }

  // Rating threshold check: after 5+ ratings, warn or block based on avg
  try {
    await checkRatingThreshold(ratedUserId);
  } catch (e) {
    if (e.code !== '42P01') logger.warn('Rating threshold check failed:', e.message);
  }

  return { message: 'Rating submitted', rated_user_id: ratedUserId };
}

/**
 * Latest reviews for a user (rated_user_id). DB keeps full history; only the newest
 * REVIEWS_WINDOW_MAX rows are addressable through this API (offset must stay within window).
 */
async function getReviewsForUser(ratedUserId, page, limit) {
  await rideRatingsRepository.ensureTable();
  const total = await rideRatingsRepository.countByRatedUserId(ratedUserId);
  const lim = Math.max(1, Math.min(limit, REVIEWS_WINDOW_MAX));
  const p = Math.max(1, page);
  const off = (p - 1) * lim;
  if (off >= REVIEWS_WINDOW_MAX) {
    return {
      reviews: [],
      total,
      page: p,
      limit: lim,
      has_more: false,
      reviews_window_max: REVIEWS_WINDOW_MAX,
    };
  }
  const take = Math.min(lim, REVIEWS_WINDOW_MAX - off);
  const reviews = await rideRatingsRepository.listByRatedUserId(ratedUserId, take, off);
  const loadedThrough = off + reviews.length;
  const hasMoreInWindow = loadedThrough < Math.min(total, REVIEWS_WINDOW_MAX);
  return {
    reviews,
    total,
    page: p,
    limit: lim,
    has_more: hasMoreInWindow,
    reviews_window_max: REVIEWS_WINDOW_MAX,
  };
}

/**
 * Get rating summary for a user (full totals from DB + latest review time for cache sync)
 */
async function getRatingSummary(userId) {
  await rideRatingsRepository.ensureTable();
  const raw = await rideRatingsRepository.getSummaryByUserId(userId);
  return {
    user_id: userId,
    total_ratings: raw.total_ratings,
    average_rating: Math.round(raw.average_rating * 100) / 100,
    latest_review_at: raw.latest_review_at,
    reviews_window_max: REVIEWS_WINDOW_MAX,
  };
}

/**
 * One round-trip friendly payload: summary + up to REVIEWS_WINDOW_MAX newest reviews.
 */
async function getReviewBundleForUser(userId) {
  await rideRatingsRepository.ensureTable();
  const [raw, reviews] = await Promise.all([
    rideRatingsRepository.getSummaryByUserId(userId),
    rideRatingsRepository.listByRatedUserId(userId, REVIEWS_WINDOW_MAX, 0),
  ]);
  const total = raw.total_ratings;
  return {
    user_id: userId,
    total_ratings: total,
    average_rating: Math.round(raw.average_rating * 100) / 100,
    latest_review_at: raw.latest_review_at,
    reviews,
    reviews_window_max: REVIEWS_WINDOW_MAX,
    has_more: total > reviews.length,
  };
}

const RATING_THRESHOLD_MIN_COUNT = 5;
const RATING_THRESHOLD_WARNING = 2.0;
const RATING_THRESHOLD_BLOCK = 1.5;
const RATING_BLOCK_DAYS = 7;

async function checkRatingThreshold(userId) {
  const summary = await rideRatingsRepository.getSummaryByUserId(userId);
  if (summary.total_ratings < RATING_THRESHOLD_MIN_COUNT) return;

  const avg = parseFloat(summary.average_rating);
  if (avg >= RATING_THRESHOLD_WARNING) return;

  const monthKey = new Date().toISOString().slice(0, 7);

  if (avg < RATING_THRESHOLD_BLOCK) {
    // Auto-block: avg < 1.5 with 5+ ratings
    const blockedUntil = new Date(Date.now() + RATING_BLOCK_DAYS * 24 * 60 * 60 * 1000);
    try {
      await pool.query(
        `INSERT INTO driver_abuse_flags (user_id, flag_type, reason, month_window, violation_count, blocked_until)
         VALUES ($1, 'low_avg_rating_block', $2, $3, $4, $5)`,
        [
          userId,
          `Average rating ${avg.toFixed(2)} (${summary.total_ratings} ratings) — below ${RATING_THRESHOLD_BLOCK} threshold. Auto-blocked for ${RATING_BLOCK_DAYS} days.`,
          monthKey,
          summary.total_ratings,
          blockedUntil,
        ]
      );
    } catch (e) {
      if (e.code !== '42P01') logger.warn('Rating block flag insert failed:', e.message);
    }

    try {
      await pool.query(
        `UPDATE users SET cancel_blocked_until = $2 WHERE id = $1`,
        [userId, blockedUntil.toISOString()]
      );
    } catch (_) {}

    try {
      const n = await pool.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'account_warning',
           'Account restricted — low ratings',
           'Your account has been temporarily restricted due to consistently low ratings. Please improve your service quality.',
           $2::jsonb)
         RETURNING id, user_id, type, title, body, data, created_at, is_read`,
        [userId, JSON.stringify({ avg_rating: avg, total_ratings: summary.total_ratings, blocked_until: blockedUntil.toISOString(), reason: 'low_avg_rating_block' })]
      );
      if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
    } catch (_) {}

    logger.info(`Driver ${userId} blocked ${RATING_BLOCK_DAYS}d — avg rating ${avg.toFixed(2)} (${summary.total_ratings} ratings)`);
  } else {
    // Warning: avg < 2.0 but >= 1.5
    const alreadyWarned = await pool.query(
      `SELECT 1 FROM driver_abuse_flags
       WHERE user_id = $1 AND flag_type = 'low_avg_rating_warning' AND month_window = $2 LIMIT 1`,
      [userId, monthKey]
    );
    if (alreadyWarned.rows.length > 0) return;

    try {
      await pool.query(
        `INSERT INTO driver_abuse_flags (user_id, flag_type, reason, month_window, violation_count)
         VALUES ($1, 'low_avg_rating_warning', $2, $3, $4)`,
        [
          userId,
          `Average rating ${avg.toFixed(2)} (${summary.total_ratings} ratings) — below ${RATING_THRESHOLD_WARNING} threshold. Warning issued.`,
          monthKey,
          summary.total_ratings,
        ]
      );
    } catch (e) {
      if (e.code !== '42P01') logger.warn('Rating warning flag insert failed:', e.message);
    }

    try {
      const n = await pool.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'account_warning',
           'Warning: Your ratings are low',
           'Your average rating has dropped below 2 stars. Continued low ratings may result in account restrictions. Please ensure a good experience for passengers.',
           $2::jsonb)
         RETURNING id, user_id, type, title, body, data, created_at, is_read`,
        [userId, JSON.stringify({ avg_rating: avg, total_ratings: summary.total_ratings, reason: 'low_avg_rating_warning' })]
      );
      if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
    } catch (_) {}

    logger.info(`Driver ${userId} warned — avg rating ${avg.toFixed(2)} (${summary.total_ratings} ratings)`);
  }
}

async function getRatingContext(bookingId, userId) {
  const booking = await pool.query(
    `SELECT b.id, b.passenger_id, b.seat_numbers, b.status,
            t.driver_id, t.from_location, t.to_location,
            p.name AS passenger_name, p.profile_image_url AS passenger_photo,
            d.name AS driver_name, d.profile_image_url AS driver_photo
     FROM bookings b
     JOIN trips t ON b.trip_id = t.id
     JOIN users p ON b.passenger_id = p.id
     JOIN users d ON t.driver_id = d.id
     WHERE b.id = $1`,
    [bookingId]
  );
  const bk = booking.rows[0];
  if (!bk) throw ApiError.notFound('Booking not found');

  let fromRole;
  if (bk.passenger_id === userId) fromRole = ROLES.PASSENGER;
  else if (bk.driver_id === userId) fromRole = ROLES.DRIVER;
  else throw ApiError.forbidden('You can only view your own booking');

  await rideRatingsRepository.ensureTable();
  const existing = await rideRatingsRepository.findByBookingAndRole(bookingId, fromRole);
  const isAutoRating = existing && (existing.comment || '').startsWith('Auto-rating:');
  const alreadyRated = existing && !isAutoRating;

  const targetName = fromRole === ROLES.PASSENGER ? bk.driver_name : bk.passenger_name;
  const rawPhoto = fromRole === ROLES.PASSENGER ? bk.driver_photo : bk.passenger_photo;
  const targetPhoto = rawPhoto && !rawPhoto.startsWith('data:') ? rawPhoto : null;
  const seats = Array.isArray(bk.seat_numbers) ? bk.seat_numbers : [];
  const route = [bk.from_location, bk.to_location].filter(Boolean).join(' → ') || '';

  return {
    booking_id: bookingId,
    from_role: fromRole,
    target_name: targetName || 'User',
    target_photo: targetPhoto,
    seat_numbers: fromRole === ROLES.DRIVER ? seats : [],
    trip_route: route,
    already_rated: alreadyRated,
  };
}

module.exports = {
  submitRating,
  getReviewsForUser,
  getRatingSummary,
  getReviewBundleForUser,
  checkRatingThreshold,
  getRatingContext,
  RATING_COMMENT_MAX_WORDS,
};
