const express = require('express');
const router = express.Router();
const Joi = require('joi');
const { createBooking, respondToBooking, getMyBookings } = require('../controllers/bookingController');
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

router.put(
  '/:id/respond',
  authenticate,
  authorize('driver'),
  validate(respondSchema),
  respondToBooking
);

module.exports = router;
