const express = require('express');
const router = express.Router();
const {
  submitVerification,
  getMyStatus
} = require('../controllers/driverVerificationController');
const { authenticate } = require('../middleware/auth');

/**
 * @route   POST /api/driver-verification
 * @desc    Submit driver verification documents
 * @access  Private
 */
router.post('/', authenticate, submitVerification);

/**
 * @route   GET /api/driver-verification
 * @desc    Get current user's verification status
 * @access  Private
 */
router.get('/', authenticate, getMyStatus);

module.exports = router;
