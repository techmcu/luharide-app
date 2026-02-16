const express = require('express');
const router = express.Router();
const { getMyReviews, getReviewsForUser, getUserRatingSummary } = require('../controllers/reviewController');
const { authenticate } = require('../middleware/auth');

router.get('/my-reviews', authenticate, getMyReviews);
router.get('/user/:userId/summary', authenticate, getUserRatingSummary);
router.get('/summary/:userId', authenticate, getUserRatingSummary); // alternate path
router.get('/user/:userId/reviews', authenticate, getReviewsForUser);

module.exports = router;
