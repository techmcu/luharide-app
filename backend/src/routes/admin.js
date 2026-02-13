const express = require('express');
const router = express.Router();
const {
  getPendingRequests,
  approveRequest,
  rejectRequest
} = require('../controllers/driverVerificationController');
const { authenticate, authorize } = require('../middleware/auth');

/**
 * @route   GET /api/admin/driver-requests
 * @desc    Get all pending driver verification requests
 * @access  Private (union_admin only)
 */
router.get(
  '/driver-requests',
  authenticate,
  authorize('union_admin'),
  getPendingRequests
);

/**
 * @route   POST /api/admin/driver-requests/:id/approve
 * @desc    Approve driver verification request
 * @access  Private (union_admin only)
 */
router.post(
  '/driver-requests/:id/approve',
  authenticate,
  authorize('union_admin'),
  approveRequest
);

/**
 * @route   POST /api/admin/driver-requests/:id/reject
 * @desc    Reject driver verification request
 * @access  Private (union_admin only)
 */
router.post(
  '/driver-requests/:id/reject',
  authenticate,
  authorize('union_admin'),
  rejectRequest
);

module.exports = router;
