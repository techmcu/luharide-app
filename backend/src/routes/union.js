const express = require('express');
const router = express.Router();
const Joi = require('joi');
const {
  createTripForDriver,
  getUnionTrips,
  getDashboardStats
} = require('../controllers/unionTripController');
const {
  getMyUnion,
  registerUnion,
  listUnions,
  approveUnion,
  rejectUnion,
  getUnionDrivers,
  addUnionDriver,
  getUnionRoutes,
  addUnionRoute,
  createUnionSchedulesBulk,
  getUnionSchedules,
  cancelUnionSchedule,
  getUnionSchedulePoster,
  getUnionCombinedPoster,
  updateUnionBranding,
  updateUnionDocuments,
} = require('../controllers/unionController');
const { authenticate, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validation');
const { cancelScheduleLimiter, unionPosterLimiter } = require('../middleware/rateLimiter');

// Validation schema for creating trip for driver
const createTripForDriverSchema = Joi.object({
  driver_id: Joi.string().uuid().required(),
  from_location: Joi.string().required().min(2).max(100),
  to_location: Joi.string().required().min(2).max(100),
  departure_time: Joi.date().iso().required(),
  fare_per_seat: Joi.number().positive().required(),
  total_seats: Joi.number().integer().min(1).max(10).default(7),
  vehicle_number: Joi.string().required().max(20),
  stops: Joi.array().items(Joi.string()).default([])
});

const addUnionDriverSchema = Joi.object({
  name: Joi.string().min(2).max(100).required(),
  vehicle_number: Joi.string().max(32).required(),
  phone: Joi.string().max(20).allow('', null),
  whatsapp_number: Joi.string().max(20).allow('', null),
});

const addUnionRouteSchema = Joi.object({
  from_location: Joi.string().min(2).max(100).required(),
  to_location: Joi.string().min(2).max(100).required(),
});

const createSchedulesSchema = Joi.object({
  from_location: Joi.string().min(2).max(100).required(),
  to_location: Joi.string().min(2).max(100).required(),
  departure_time: Joi.date().iso().required(),
  union_driver_ids: Joi.array().items(Joi.string().uuid()).min(1).required(),
});

const updateBrandingSchema = Joi.object({
  poster_header: Joi.string().max(200).allow('', null),
  poster_custom_text: Joi.string().max(120).allow('', null),
  poster_custom_text_position: Joi.string()
    .valid('left', 'right', 'none')
    .allow('', null),
  poster_layout_type: Joi.string().valid('classic', 'compact')
    .allow('', null),
  poster_theme: Joi.string()
    .valid('saffron', 'sky', 'mint', 'rose')
    .allow('', null),
});

// Union registration (any authenticated user) — must list all fields (stripUnknown removes the rest)
const registerUnionSchema = Joi.object({
  name: Joi.string().min(3).max(200).required(),
  location: Joi.string().min(3).max(200).required(),
  contact_phone: Joi.string().min(10).max(20).required(),
  contact_email: Joi.string().email().required(),
  owner_name: Joi.string().max(100).allow('', null),
  owner_aadhaar_url: Joi.string().max(2048).allow('', null),
  owner_aadhaar_front_url: Joi.string().min(3).max(2048).required(),
  owner_aadhaar_back_url: Joi.string().min(3).max(2048).required(),
  office_photo_url: Joi.string().min(3).max(2048).required(),
  union_photo_url: Joi.string().max(2048).allow('', null),
  union_driver_list_photo_url: Joi.string().max(2048).allow('', null),
  leader_driving_license_front_url: Joi.string().max(2048).allow('', null),
  leader_driving_license_back_url: Joi.string().max(2048).allow('', null),
  owner_vehicle_rc_url: Joi.string().max(2048).allow('', null),
  owner_vehicle_rc_front_url: Joi.string().max(2048).allow('', null),
  owner_vehicle_rc_back_url: Joi.string().max(2048).allow('', null),
  union_share_notes: Joi.string().max(500).allow('', null),
});

router.post(
  '/register',
  authenticate,
  validate(registerUnionSchema),
  registerUnion
);

// Current user's union + status
router.get('/me', authenticate, getMyUnion);

// Union admin: update poster branding (custom header text)
router.patch(
  '/branding',
  authenticate,
  authorize('union_admin'),
  validate(updateBrandingSchema),
  updateUnionBranding
);

// Union admin: update KYC document URLs + optional stand/share notes
router.patch(
  '/me/documents',
  authenticate,
  authorize('union_admin'),
  updateUnionDocuments
);

// Platform admin: list / approve / reject unions
router.get('/admin/unions', authenticate, listUnions);
router.post('/admin/unions/:id/approve', authenticate, approveUnion);
router.post('/admin/unions/:id/reject', authenticate, rejectUnion);

// Union admin: basic read-only drivers list
router.get(
  '/drivers',
  authenticate,
  authorize('union_admin'),
  getUnionDrivers
);

// Union admin: add driver to union list
router.post(
  '/drivers',
  authenticate,
  authorize('union_admin'),
  validate(addUnionDriverSchema),
  addUnionDriver
);

// Union admin: preset routes
router.get(
  '/routes',
  authenticate,
  authorize('union_admin'),
  getUnionRoutes
);

router.post(
  '/routes',
  authenticate,
  authorize('union_admin'),
  validate(addUnionRouteSchema),
  addUnionRoute
);

// Union admin: bulk schedules/rides creation
router.post(
  '/schedules/bulk',
  authenticate,
  authorize('union_admin'),
  validate(createSchedulesSchema),
  createUnionSchedulesBulk
);

// Union admin: view schedules
router.get(
  '/schedules',
  authenticate,
  authorize('union_admin'),
  getUnionSchedules
);

// Union admin: cancel a schedule
router.delete(
  '/schedules/:id',
  authenticate,
  authorize('union_admin'),
  cancelScheduleLimiter,
  cancelUnionSchedule
);

// Union admin: generate combined PDF poster for multiple schedules (one page)
// IMPORTANT: this route must come BEFORE /schedules/:id/poster so 'combined' isn't treated as an id
router.get(
  '/schedules/poster-combined',
  authenticate,
  authorize('union_admin'),
  unionPosterLimiter,
  getUnionCombinedPoster
);

// Union admin: generate PDF poster for a single schedule
router.get(
  '/schedules/:id/poster',
  authenticate,
  authorize('union_admin'),
  unionPosterLimiter,
  getUnionSchedulePoster
);

// Union Admin routes (after registration / role upgrade)
router.get('/dashboard', authenticate, authorize('union_admin'), getDashboardStats);

// Create trip for a driver in union
router.post(
  '/trips',
  authenticate,
  authorize('union_admin'),
  validate(createTripForDriverSchema),
  createTripForDriver
);

// Get all trips for union drivers
router.get(
  '/trips',
  authenticate,
  authorize('union_admin'),
  getUnionTrips
);

module.exports = router;
