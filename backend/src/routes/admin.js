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
const {
  grantDriverReverify,
  grantUnionReverify,
  listPendingUnionDocRequests,
  approveUnionDocRequest,
  rejectUnionDocRequest,
} = require('../controllers/kycAdminController');
const { streamAdminKycDocumentFile } = require('../controllers/kycDocumentStreamController');
const {
  listIndependentDriversDirectory,
  listUnionsDirectory,
} = require('../controllers/adminDirectoryController');
const { authenticate, authorizeKycAdmin } = require('../middleware/auth');

/**
 * @route   GET /api/admin/driver-requests
 * @desc    Get all pending driver verification requests
 * @access  Private (union_admin only)
 */
router.get(
  '/driver-requests',
  authenticate,
  authorizeKycAdmin,
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
  authorizeKycAdmin,
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
  authorizeKycAdmin,
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
  authorizeKycAdmin,
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
  authorizeKycAdmin,
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
  authorizeKycAdmin,
  rejectUnionRequest
);

/**
 * KYC admin utilities (union_admin only)
 * - Driver reverify: revoke blue tick + open 1-time re-upload window
 * - Union reverify: revoke union docs blue tick + open 1-time re-upload window
 * - Union document review: approve/reject updates submitted by union admin
 */
router.post(
  '/kyc/drivers/:userId/reverify',
  authenticate,
  authorizeKycAdmin,
  grantDriverReverify
);

router.post(
  '/kyc/unions/:unionId/reverify',
  authenticate,
  authorizeKycAdmin,
  grantUnionReverify
);

router.get(
  '/union-doc-requests',
  authenticate,
  authorizeKycAdmin,
  listPendingUnionDocRequests
);

/** Scrollable directory lists (read replica when configured) */
router.get(
  '/directory/independent-drivers',
  authenticate,
  authorizeKycAdmin,
  listIndependentDriversDirectory
);

router.get(
  '/directory/unions',
  authenticate,
  authorizeKycAdmin,
  listUnionsDirectory
);

/**
 * Authenticated KYC file stream (same-origin /api — reliable on Flutter web).
 * Query: path=/uploads/driver-docs/...
 */
router.get(
  '/document-file',
  authenticate,
  authorizeKycAdmin,
  streamAdminKycDocumentFile
);

router.post(
  '/union-doc-requests/:id/approve',
  authenticate,
  authorizeKycAdmin,
  approveUnionDocRequest
);

router.post(
  '/union-doc-requests/:id/reject',
  authenticate,
  authorizeKycAdmin,
  rejectUnionDocRequest
);

module.exports = router;
