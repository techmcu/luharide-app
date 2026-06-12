const express = require('express');
const router = express.Router();
const { getMyReviews, getReviewsForUser, getUserRatingSummary, getUserReviewBundle } = require('../controllers/reviewController');
const { authenticate } = require('../middleware/auth');
const { redisCache } = require('../middleware/redisCache');
const { reviewReadLimiter } = require('../middleware/rateLimiter');
const ApiError = require('../utils/ApiError');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function validateUserIdParam(req, res, next) {
  if (!UUID_RE.test(req.params.userId)) {
    return next(ApiError.badRequest('Invalid user ID format'));
  }
  next();
}

// My reviews — requires auth
router.get('/my-reviews', authenticate, getMyReviews);

// Public: anyone can see a user's rating summary and reviews (no login needed)
// Rate limited + Redis cached (120s) to minimise DB load and prevent scraping
router.get('/user/:userId/summary', reviewReadLimiter, validateUserIdParam, redisCache(120), getUserRatingSummary);
router.get('/summary/:userId', reviewReadLimiter, validateUserIdParam, redisCache(120), getUserRatingSummary);
router.get('/user/:userId/bundle', reviewReadLimiter, validateUserIdParam, redisCache(120), getUserReviewBundle);
router.get('/user/:userId/reviews', reviewReadLimiter, validateUserIdParam, redisCache(120), getReviewsForUser);

module.exports = router;
