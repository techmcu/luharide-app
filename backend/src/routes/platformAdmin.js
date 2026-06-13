const express = require('express');
const router = express.Router();
const { authenticate, authorizePlatformAdmin } = require('../middleware/auth');
const { adminDashboardLimiter, adminBulkNotifyLimiter } = require('../middleware/rateLimiter');
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
  getDailyStats,
  exportStatsCsv,
  getUnionFcmSettings,
  toggleGlobalUnionFcm,
  toggleUnionFcm,
  getDbHealth,
  getFlaggedDrivers,
  resolveFlaggedDriver,
  deleteRating,
  banDriver,
  unbanDriver,
} = require('../controllers/platformAdminController');

const guard = [authenticate, authorizePlatformAdmin];

// User-facing complaint endpoints (any authenticated user) — MUST be before :id routes
router.post('/complaints/submit', authenticate, submitComplaint);
router.get('/complaints/mine', authenticate, getMyComplaints);

// Phase 1 — Dashboard, Users, Trips, Revenue
router.get('/dashboard', ...guard, adminDashboardLimiter, getDashboard);
router.get('/users', ...guard, adminDashboardLimiter, getUsers);
router.get('/users/:id', ...guard, adminDashboardLimiter, getUserDetail);
router.patch('/users/:id/active', ...guard, toggleUserActive);
router.get('/trips', ...guard, adminDashboardLimiter, getTrips);
router.get('/trips/:id', ...guard, adminDashboardLimiter, getTripDetail);
router.post('/trips/:id/cancel', ...guard, cancelTrip);
router.get('/revenue', ...guard, adminDashboardLimiter, getRevenueOverview);
router.get('/daily-stats', ...guard, adminDashboardLimiter, getDailyStats);
router.get('/export-csv', ...guard, adminDashboardLimiter, exportStatsCsv);

// Phase 2 — Notifications, Complaints, Config
router.post('/notifications/bulk', ...guard, adminBulkNotifyLimiter, sendBulkNotification);
router.get('/notifications/history', ...guard, getBroadcastHistory);
router.get('/complaints', ...guard, getComplaints);
router.get('/complaints/:id', ...guard, getComplaintDetail);
router.post('/complaints/:id/resolve', ...guard, resolveComplaint);
router.get('/config', ...guard, getAppConfig);
router.patch('/config', ...guard, updateAppConfig);

// Phase 3 — Union FCM Management
router.get('/union-fcm', ...guard, getUnionFcmSettings);
router.patch('/union-fcm/global', ...guard, toggleGlobalUnionFcm);
router.patch('/union-fcm/:unionId', ...guard, toggleUnionFcm);

// Phase 4 — DB Health
router.get('/db-health', ...guard, getDbHealth);

// Phase 5 — Flagged Drivers & Admin Controls
router.get('/flagged-drivers', ...guard, getFlaggedDrivers);
router.patch('/flagged-drivers/:id/resolve', ...guard, resolveFlaggedDriver);
router.delete('/ratings/:id', ...guard, deleteRating);
router.post('/users/:id/ban', ...guard, banDriver);
router.post('/users/:id/unban', ...guard, unbanDriver);

module.exports = router;
