const express = require('express');
const router = express.Router();
const { authenticate, authorize } = require('../middleware/auth');
const {
  getDashboard,
  getUsers,
  getUserDetail,
  toggleUserActive,
  getTrips,
  getTripDetail,
  cancelTrip,
  getRevenueOverview,
} = require('../controllers/platformAdminController');

const guard = [authenticate, authorize('union_admin')];

router.get('/dashboard', ...guard, getDashboard);
router.get('/users', ...guard, getUsers);
router.get('/users/:id', ...guard, getUserDetail);
router.patch('/users/:id/active', ...guard, toggleUserActive);
router.get('/trips', ...guard, getTrips);
router.get('/trips/:id', ...guard, getTripDetail);
router.post('/trips/:id/cancel', ...guard, cancelTrip);
router.get('/revenue', ...guard, getRevenueOverview);

module.exports = router;
