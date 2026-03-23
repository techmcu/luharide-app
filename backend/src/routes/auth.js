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

// Validation schemas (flat body: phone, email, otp, etc.)
const sendOTPSchema = Joi.object({
  phone: Joi.string().pattern(/^[6-9]\d{9}$/).optional().allow('', null),
  email: Joi.string().email().optional().allow('', null),
  purpose: Joi.string().valid('login', 'registration').optional()
}).or('phone', 'email').messages({
  'object.missing': 'Provide either phone or email'
});

const verifyOTPSchema = Joi.object({
  phone: Joi.string().pattern(/^[6-9]\d{9}$/).optional().allow('', null),
  email: Joi.string().email().optional().allow('', null),
  otp: schemas.otp,
  name: Joi.string().min(2).max(100).optional(),
  role: Joi.string().valid('passenger', 'driver', 'union_admin').optional(),
  password: Joi.string().min(6).max(128).optional(), // for email signup: set password on new user
  platform: Joi.string().optional()
}).or('phone', 'email').messages({
  'object.missing': 'Provide either phone or email'
});

const refreshTokenSchema = Joi.object({
  refreshToken: Joi.string().required(),
  platform: Joi.string().optional()
});

const updateProfileSchema = Joi.object({
  name: Joi.string().min(2).max(100).optional(),
  phone: Joi.string().pattern(/^[6-9]\d{9}$/).optional().allow('', null),
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
 * @desc    Logout user - revokes refresh token (no auth needed, so expired tokens can still logout)
 * @access  Public (requires refreshToken in body)
 */
router.post('/logout', logoutController);

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
