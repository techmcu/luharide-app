const express = require('express');
const router = express.Router();
const Joi = require('joi');
const {
  createTrip,
  searchTrips,
  getTripDetails,
  getMyTrips,
  getLocationSuggestions,
  estimateRoute,
  getTripBookings,
  getTripBookedSeats,
  getRecentRoutes,
  saveRecentRoute,
  startTrip,
  completeTrip,
  cancelTrip,
  deleteTrip
} = require('../controllers/tripController');
const { authenticate, authorize, optionalAuth } = require('../middleware/auth');
const { validate } = require('../middleware/validation');
const { redisCache } = require('../middleware/redisCache');
const { searchLimiter, writeLimiter, stateChangeLimiter, destructiveLimiter } = require('../middleware/rateLimiter');

// Validation schemas
const createTripSchema = Joi.object({
  from_location: Joi.string().required().min(2).max(200).trim(),
  to_location: Joi.string().required().min(2).max(200).trim(),
  departure_time: Joi.date().iso().required(),
  fare_per_seat: Joi.number().positive().required(),
  total_seats: Joi.number().integer().min(2).max(32).default(7),
  vehicle_number: Joi.string().allow('').max(20).trim().default(''), // backend uses verified vehicle if empty
  stops: Joi.array().items(Joi.string().max(200)).max(20).default([]),
  require_approval: Joi.boolean().default(false), // false = auto-approve (driver can turn on manually)
  // Optional pickup/drop coordinates (from location autocomplete). When present,
  // backend computes road distance and enforces the distance-based max fare.
  from_lat: Joi.number().min(-90).max(90).optional(),
  from_lng: Joi.number().min(-180).max(180).optional(),
  to_lat: Joi.number().min(-90).max(90).optional(),
  to_lng: Joi.number().min(-180).max(180).optional()
});

// Public routes
router.get('/search', searchLimiter, redisCache(30), searchTrips);
router.get('/locations', redisCache(300), getLocationSuggestions);
router.get('/estimate', searchLimiter, redisCache(300), estimateRoute);
// IMPORTANT: Specific routes MUST be before /:id (else "my-trips" matches as :id)
router.get('/my-trips', authenticate, authorize('driver'), getMyTrips);
router.get('/recent-routes', authenticate, getRecentRoutes);
router.post('/recent-routes', authenticate, writeLimiter, saveRecentRoute);
router.get('/:id/bookings', authenticate, authorize('driver'), getTripBookings);
router.get('/:id/booked-seats', getTripBookedSeats);
router.get('/:id', searchLimiter, optionalAuth, getTripDetails);

router.put('/:id/start', authenticate, authorize('driver'), stateChangeLimiter, startTrip);
router.put('/:id/complete', authenticate, authorize('driver'), stateChangeLimiter, completeTrip);
router.put('/:id/cancel', authenticate, authorize('driver'), stateChangeLimiter, cancelTrip);

// Protected routes (Driver only - Individual drivers can create their own trips)
// Union admins will have separate endpoints to create trips for their drivers
router.post(
  '/',
  authenticate,
  authorize('driver'),
  writeLimiter,
  validate(createTripSchema),
  createTrip
);

router.delete(
  '/:id',
  authenticate,
  authorize('driver'),
  destructiveLimiter,
  deleteTrip
);

module.exports = router;
