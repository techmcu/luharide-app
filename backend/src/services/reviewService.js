/**
 * Service: review/rating business logic
 * OOP: single responsibility – validation, role resolution, orchestration
 * No DB details here; uses repositories
 */
const ApiError = require('../utils/ApiError');
const { RATING, RATING_COMMENT_MAX_WORDS, ROLES } = require('../constants/validation');
const rideRatingsRepository = require('../repositories/rideRatingsRepository');
const bookingRepository = require('../repositories/bookingRepository');

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
  });

  return { message: 'Rating submitted' };
}

/**
 * Get paginated reviews for a user (rated_user_id)
 */
async function getReviewsForUser(ratedUserId, page, limit) {
  await rideRatingsRepository.ensureTable();
  const total = await rideRatingsRepository.countByRatedUserId(ratedUserId);
  const reviews = await rideRatingsRepository.listByRatedUserId(ratedUserId, page, limit);
  return { reviews, total, page, limit, has_more: (page - 1) * limit + reviews.length < total };
}

/**
 * Get rating summary for a user
 */
async function getRatingSummary(userId) {
  await rideRatingsRepository.ensureTable();
  const raw = await rideRatingsRepository.getSummaryByUserId(userId);
  return {
    user_id: userId,
    total_ratings: raw.total_ratings,
    average_rating: Math.round(raw.average_rating * 100) / 100,
  };
}

module.exports = {
  submitRating,
  getReviewsForUser,
  getRatingSummary,
  RATING_COMMENT_MAX_WORDS,
};
