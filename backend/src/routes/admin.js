const express = require('express');
const router = express.Router();
const {
  getPendingRequests,
  approveRequest,
  rejectRequest
} = require('../controllers/driverVerificationController');
const {
  getPendingUnionRequests,
  approveUnionRequest,
  rejectUnionRequest,
} = require('../controllers/unionController');
const { authenticate, authorize } = require('../middleware/auth');
const { requireApprovePassword } = require('../middleware/approvePassword');

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
  requireApprovePassword,
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

/**
 * @route   GET /api/admin/union-requests
 * @desc    Get all pending union registration requests
 * @access  Private (union_admin only)
 */
router.get(
  '/union-requests',
  authenticate,
  authorize('union_admin'),
  getPendingUnionRequests
);

/**
 * @route   POST /api/admin/union-requests/:id/approve
 * @desc    Approve union registration request
 * @access  Private (union_admin only)
 */
router.post(
  '/union-requests/:id/approve',
  authenticate,
  authorize('union_admin'),
  requireApprovePassword,
  approveUnionRequest
);

/**
 * @route   POST /api/admin/union-requests/:id/reject
 * @desc    Reject union registration request
 * @access  Private (union_admin only)
 */
router.post(
  '/union-requests/:id/reject',
  authenticate,
  authorize('union_admin'),
  rejectUnionRequest
);

module.exports = router;
