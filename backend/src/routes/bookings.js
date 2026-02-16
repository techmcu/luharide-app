const express = require('express');
const router = express.Router();
const Joi = require('joi');
const { createBooking, respondToBooking, getMyBookings, cancelBooking } = require('../controllers/bookingController');
const { submitRating } = require('../controllers/reviewController');
const { authenticate, authorize } = require('../middleware/auth');
const { validate } = require('../middleware/validation');

const createBookingSchema = Joi.object({
  trip_id: Joi.string().uuid().required(),
  seat_numbers: Joi.array().items(Joi.number().integer().min(1)).min(1).required()
});

const respondSchema = Joi.object({
  action: Joi.string().valid('accept', 'reject').required()
});

router.post(
  '/',
  authenticate,
  authorize('passenger'),
  validate(createBookingSchema),
  createBooking
);

router.get('/my-bookings', authenticate, authorize('passenger'), getMyBookings);

router.post(
  '/:id/cancel',
  authenticate,
  authorize('passenger'),
  cancelBooking
);

router.put(
  '/:id/respond',
  authenticate,
  authorize('driver'),
  validate(respondSchema),
  respondToBooking
);

const rateSchema = Joi.object({
  rating: Joi.number().integer().min(1).max(5).required(),
  comment: Joi.string().allow('').max(500).optional()
});

router.post(
  '/:id/rate',
  authenticate,
  validate(rateSchema),
  submitRating
);

module.exports = router;
