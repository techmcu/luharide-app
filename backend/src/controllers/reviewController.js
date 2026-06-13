/**
 * Controller: HTTP only – parse request, call service, send response
 * System design: thin controller; business logic in service, data access in repository
 */
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const { clampPage, clampReviewLimit, MAX_REVIEW_PAGE_SIZE, REVIEWS_WINDOW_MAX } = require('../constants/pagination');
const reviewService = require('../services/reviewService');

/**
 * POST /api/bookings/:id/rate
 * Body: { rating: 1-5, comment?: string }
 */
const submitRating = asyncHandler(async (req, res) => {
  const bookingId = req.params.id;
  const userId = req.user.id;
  const { rating, comment } = req.body;

  const payload = await reviewService.submitRating(bookingId, userId, { rating, comment });

  ApiResponse.created(
    payload,
    'Thank you for your rating'
  ).send(res);
});

/**
 * GET /api/reviews/my-reviews?page=1&limit=20
 */
const getMyReviews = asyncHandler(async (req, res) => {
  const userId = req.user.id;
  const page = clampPage(req.query.page);
  const limit = clampReviewLimit(req.query.limit);

  const data = await reviewService.getReviewsForUser(userId, page, limit);

  ApiResponse.success(
    {
      ...data,
      reviews_api_max_per_page: MAX_REVIEW_PAGE_SIZE,
      reviews_window_max: data.reviews_window_max ?? REVIEWS_WINDOW_MAX,
    },
    'Reviews retrieved'
  ).send(res);
});

/**
 * GET /api/reviews/user/:userId/reviews?page=1&limit=20
 */
const getReviewsForUser = asyncHandler(async (req, res) => {
  const { userId } = req.params;
  const page = clampPage(req.query.page);
  const limit = clampReviewLimit(req.query.limit);

  const data = await reviewService.getReviewsForUser(userId, page, limit);

  ApiResponse.success(
    {
      ...data,
      reviews_api_max_per_page: MAX_REVIEW_PAGE_SIZE,
      reviews_window_max: data.reviews_window_max ?? REVIEWS_WINDOW_MAX,
    },
    'Reviews retrieved'
  ).send(res);
});

/**
 * GET /api/reviews/user/:userId/summary or GET /api/reviews/summary/:userId
 */
const getUserRatingSummary = asyncHandler(async (req, res) => {
  const userId = req.params.userId;
  const data = await reviewService.getRatingSummary(userId);
  ApiResponse.success(data, 'Rating summary').send(res);
});

/**
 * GET /api/reviews/user/:userId/bundle — summary + latest reviews in one response (client cache friendly)
 */
const getUserReviewBundle = asyncHandler(async (req, res) => {
  const userId = req.params.userId;
  const data = await reviewService.getReviewBundleForUser(userId);
  ApiResponse.success(data, 'Reviews bundle').send(res);
});

const getRatingContext = asyncHandler(async (req, res) => {
  const bookingId = req.params.id;
  const userId = req.user.id;
  const data = await reviewService.getRatingContext(bookingId, userId);
  ApiResponse.success(data, 'Rating context').send(res);
});

module.exports = {
  submitRating,
  getMyReviews,
  getReviewsForUser,
  getUserRatingSummary,
  getUserReviewBundle,
  getRatingContext,
};
