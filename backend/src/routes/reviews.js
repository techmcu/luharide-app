const express = require('express');
const router = express.Router();
const { getMyReviews, getReviewsForUser, getUserRatingSummary, getUserReviewBundle } = require('../controllers/reviewController');
const { authenticate } = require('../middleware/auth');
const { redisCache } = require('../middleware/redisCache');

// My reviews — requires auth
router.get('/my-reviews', authenticate, getMyReviews);

// Public: anyone can see a user's rating summary and reviews (no login needed)
router.get('/user/:userId/summary', redisCache(60), getUserRatingSummary);
router.get('/summary/:userId', redisCache(60), getUserRatingSummary);
router.get('/user/:userId/bundle', redisCache(60), getUserReviewBundle);
router.get('/user/:userId/reviews', redisCache(60), getReviewsForUser);

module.exports = router;
