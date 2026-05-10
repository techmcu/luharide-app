const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const router = express.Router();
const { authenticate, authorize } = require('../middleware/auth');
const { adminPosterLimiter, adminBulkNotifyLimiter, adminRideCreateLimiter } = require('../middleware/rateLimiter');
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
  parsePoster,
  createAdminRide,
  getAdminRides,
} = require('../controllers/platformAdminController');

const guard = [authenticate, authorize('union_admin')];

const posterDir = path.join(__dirname, '../../uploads/posters');
if (!fs.existsSync(posterDir)) fs.mkdirSync(posterDir, { recursive: true });
const posterUpload = multer({
  storage: multer.diskStorage({
    destination: (_, __, cb) => cb(null, posterDir),
    filename: (_, file, cb) => cb(null, `poster_${Date.now()}_${Math.random().toString(36).slice(2, 8)}${path.extname(file.originalname)}`),
  }),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (_, file, cb) => {
    const ok = ['image/jpeg', 'image/png', 'application/pdf'].includes(file.mimetype);
    cb(ok ? null : new Error('Only JPEG, PNG or PDF allowed'), ok);
  },
});

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

// Phase 3 — Poster-to-Ride
router.post('/rides/parse-poster', ...guard, adminPosterLimiter, posterUpload.single('poster'), parsePoster);
router.post('/rides/create', ...guard, adminRideCreateLimiter, createAdminRide);
router.get('/rides', ...guard, getAdminRides);

module.exports = router;
