const express = require('express');
const router = express.Router();
const Joi = require('joi');
const {
  createTrip,
  searchTrips,
  getTripDetails,
  getMyTrips,
  getLocationSuggestions,
  getTripBookings,
  getTripBookedSeats,
  deleteTrip
} = require('../controllers/tripController');
const { authenticate, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validation');

// Validation schemas
const createTripSchema = Joi.object({
  from_location: Joi.string().required().min(2).max(200).trim(),
  to_location: Joi.string().required().min(2).max(200).trim(),
  departure_time: Joi.date().iso().required(),
  fare_per_seat: Joi.number().positive().required(),
  total_seats: Joi.number().integer().min(1).max(50).default(7),
  vehicle_number: Joi.string().required().min(1).max(20).trim(),
  stops: Joi.array().items(Joi.string()).default([]),
  require_approval: Joi.boolean().default(true) // true = driver must approve each booking
});

// Public routes
router.get('/search', searchTrips);
router.get('/locations', getLocationSuggestions);
// IMPORTANT: Specific routes MUST be before /:id (else "my-trips" matches as :id)
router.get('/my-trips', authenticate, authorize('driver'), getMyTrips);
router.get('/:id/bookings', authenticate, authorize('driver'), getTripBookings);
router.get('/:id/booked-seats', getTripBookedSeats);
router.get('/:id', getTripDetails);

// Protected routes (Driver only - Individual drivers can create their own trips)
// Union admins will have separate endpoints to create trips for their drivers
router.post(
  '/',
  authenticate,
  authorize('driver'),
  validate(createTripSchema),
  createTrip
);

router.delete(
  '/:id',
  authenticate,
  authorize('driver'),
  deleteTrip
);

module.exports = router;
