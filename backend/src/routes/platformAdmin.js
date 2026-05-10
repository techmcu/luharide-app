const express = require('express');
const router = express.Router();
const { authenticate, authorize } = require('../middleware/auth');
const { adminBulkNotifyLimiter } = require('../middleware/rateLimiter');
const {
  getDashboard,
  getUsers,
  getUserDetail,
  toggleUserActive,
  getTrips,
  getTripDetail,
  cancelTrip,
  getRevenueOverview,
  sendBulkNotification,
  getBroadcastHistory,
  getComplaints,
  getComplaintDetail,
  resolveComplaint,
  getAppConfig,
  updateAppConfig,
  submitComplaint,
  getMyComplaints,
} = require('../controllers/platformAdminController');

const guard = [authenticate, authorize('union_admin')];

// Phase 1 — Dashboard, Users, Trips, Revenue
router.get('/dashboard', ...guard, getDashboard);
router.get('/users', ...guard, getUsers);
router.get('/users/:id', ...guard, getUserDetail);
router.patch('/users/:id/active', ...guard, toggleUserActive);
router.get('/trips', ...guard, getTrips);
router.get('/trips/:id', ...guard, getTripDetail);
router.post('/trips/:id/cancel', ...guard, cancelTrip);
router.get('/revenue', ...guard, getRevenueOverview);

// Phase 2 — Notifications, Complaints, Config
router.post('/notifications/bulk', ...guard, adminBulkNotifyLimiter, sendBulkNotification);
router.get('/notifications/history', ...guard, getBroadcastHistory);
router.get('/complaints', ...guard, getComplaints);
router.get('/complaints/:id', ...guard, getComplaintDetail);
router.post('/complaints/:id/resolve', ...guard, resolveComplaint);
router.get('/config', ...guard, getAppConfig);
router.patch('/config', ...guard, updateAppConfig);

// User-facing complaint endpoints (any authenticated user)
router.post('/complaints/submit', authenticate, submitComplaint);
router.get('/complaints/mine', authenticate, getMyComplaints);

module.exports = router;
