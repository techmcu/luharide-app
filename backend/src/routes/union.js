const express = require('express');
const router = express.Router();
const Joi = require('joi');
const {
  createTripForDriver,
  getUnionTrips
} = require('../controllers/unionTripController');
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

// Union Admin routes
router.get('/dashboard', authenticate, authorize('union_admin'), (req, res) => {
  res.json({ message: 'Union dashboard endpoint - To be implemented' });
});

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
