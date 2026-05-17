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
  if (booking.status !== 'confirmed') {
    throw ApiError.badRequest('Can only rate after booking is confirmed');
  }

  // Rating allowed 4 minutes after booking is CONFIRMED (not departure).
  const confirmedAt = booking.confirmed_at ? new Date(booking.confirmed_at).getTime() : 0;
  if (!confirmedAt) {
    throw ApiError.badRequest('Cannot rate: confirm time unknown. Please try again later.');
  }
  const fourMinAfterConfirm = confirmedAt + 4 * 60 * 1000;
  if (Date.now() < fourMinAfterConfirm) {
    throw ApiError.badRequest('You can rate 4 minutes after your ride is confirmed. Please wait.');
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

  await rideRatingsRepository.ensureTable();
  const existing = await rideRatingsRepository.findByBookingAndRole(bookingId, fromRole);
  if (existing) throw ApiError.badRequest('You have already rated for this ride');

  await rideRatingsRepository.create({
    bookingId,
    fromUserId: userId,
    ratedUserId,
    fromRole,
    rating,
    comment: safeComment,
    tripContext: buildTripContext(booking),
  });

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

module.exports = {
  submitRating,
  getReviewsForUser,
  getRatingSummary,
  getReviewBundleForUser,
  RATING_COMMENT_MAX_WORDS,
};
