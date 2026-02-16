const express = require('express');
const router = express.Router();
const Joi = require('joi');

// Controllers
const {
  sendOTPController,
  verifyOTPController,
  refreshTokenController,
  logoutController,
  getCurrentUserController,
  updateProfileController
} = require('../controllers/authController');

// Middleware
const { authenticate } = require('../middleware/auth');
const { validate, schemas } = require('../middleware/validation');
const { otpLimiter, authLimiter } = require('../middleware/rateLimiter');

// Validation schemas
const sendOTPSchema = Joi.object({
  body: Joi.object({
    phone: schemas.phone,
    purpose: Joi.string().valid('login', 'registration').optional()
  })
});

const verifyOTPSchema = Joi.object({
  body: Joi.object({
    phone: schemas.phone,
    otp: schemas.otp,
    name: Joi.string().min(2).max(100).optional(),
    role: schemas.role.optional(),
    platform: Joi.string().optional()
  })
});

const refreshTokenSchema = Joi.object({
  body: Joi.object({
    refreshToken: Joi.string().required(),
    platform: Joi.string().optional()
  })
});

const updateProfileSchema = Joi.object({
  name: Joi.string().min(2).max(100).optional(),
  email: schemas.email,
  profile_image_url: Joi.string().max(500).optional().allow('', null),
  whatsapp_number: Joi.string().max(20).optional().allow('', null),
  bio: Joi.string().max(500).optional().allow('', null),
  luggage_allowance_per_passenger: Joi.string().max(100).optional().allow('', null)
});

// Routes

/**
 * @route   POST /api/auth/send-otp
 * @desc    Send OTP to phone number
 * @access  Public
 */
router.post('/send-otp', otpLimiter, validate(sendOTPSchema), sendOTPController);

/**
 * @route   POST /api/auth/verify-otp
 * @desc    Verify OTP and login/register
 * @access  Public
 */
router.post('/verify-otp', authLimiter, validate(verifyOTPSchema), verifyOTPController);

/**
 * @route   POST /api/auth/refresh-token
 * @desc    Refresh access token
 * @access  Public
 */
router.post('/refresh-token', validate(refreshTokenSchema), refreshTokenController);

/**
 * @route   POST /api/auth/logout
 * @desc    Logout user
 * @access  Private
 */
router.post('/logout', authenticate, logoutController);

/**
 * @route   GET /api/auth/me
 * @desc    Get current user profile
 * @access  Private
 */
router.get('/me', authenticate, getCurrentUserController);

/**
 * @route   PUT /api/auth/profile
 * @desc    Update user profile
 * @access  Private
 */
router.put('/profile', authenticate, validate(updateProfileSchema), updateProfileController);

module.exports = router;
