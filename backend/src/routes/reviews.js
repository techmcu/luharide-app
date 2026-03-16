const express = require('express');
const router = express.Router();
const { getMyReviews, getReviewsForUser, getUserRatingSummary } = require('../controllers/reviewController');
const { authenticate } = require('../middleware/auth');

// My reviews — requires auth
router.get('/my-reviews', authenticate, getMyReviews);

// Public: anyone can see a user's rating summary and reviews (no login needed)
router.get('/user/:userId/summary', getUserRatingSummary);
router.get('/summary/:userId', getUserRatingSummary);
router.get('/user/:userId/reviews', getReviewsForUser);

module.exports = router;
