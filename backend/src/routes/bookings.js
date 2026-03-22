const express = require('express');
const router = express.Router();
const Joi = require('joi');
const { createBooking, respondToBooking, getMyBookings, cancelBooking } = require('../controllers/bookingController');
const { submitRating } = require('../controllers/reviewController');
const { authenticate, authorize } = require('../middleware/auth'); // authorize used for driver-only respond
const { validate } = require('../middleware/validation');

const createBookingSchema = Joi.object({
  trip_id: Joi.string().uuid().required(),
  seat_numbers: Joi.array().items(Joi.number().integer().min(1)).min(1).required()
});

const respondSchema = Joi.object({
  action: Joi.string().valid('accept', 'reject').required()
});

// Booking is for any logged-in user (passenger / driver / union_admin / future roles).
// Do not use authorize() here — strict role strings caused 403 when DB role didn't match exactly.
router.post(
  '/',
  authenticate,
  validate(createBookingSchema),
  createBooking
);

router.get('/my-bookings', authenticate, getMyBookings);

router.post(
  '/:id/cancel',
  authenticate,
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
