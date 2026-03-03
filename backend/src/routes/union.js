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
} = require('../controllers/unionController');
const { authenticate, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validation');

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

// Union registration (any authenticated user) - goes into pending status
const registerUnionSchema = Joi.object({
  name: Joi.string().min(3).max(200).required(),
  location: Joi.string().max(200).allow('', null),
  contact_phone: Joi.string().max(20).allow('', null),
  contact_email: Joi.string().email().allow('', null),
});

router.post(
  '/register',
  authenticate,
  validate(registerUnionSchema),
  registerUnion
);

// Current user's union + status
router.get('/me', authenticate, getMyUnion);

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
  cancelUnionSchedule
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
