const express = require('express');
const router = express.Router();
const Joi = require('joi');
const {
  createTripForDriver,
  getUnionTrips,
  getDashboardStats
} = require('../controllers/unionTripController');
const { registerUnion } = require('../controllers/unionController');
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

// Union registration (any authenticated user)
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
