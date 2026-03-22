const express = require('express');
const router = express.Router();
const Joi = require('joi');

const {
  signup,
  login,
  createDemoAccounts,
  changePassword,
  requestPasswordReset,
  resetPassword
} = require('../controllers/simpleAuthController');

const { validate } = require('../middleware/validation');
const { authenticate } = require('../middleware/auth');
const {
  simpleAuthLoginLimiter,
  simpleAuthSignupLimiter,
  simpleAuthForgotPasswordLimiter,
  simpleAuthResetPasswordLimiter,
  simpleAuthChangePasswordLimiter
} = require('../middleware/rateLimiter');

// Validation schemas
const signupSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(6).required(),
  name: Joi.string().min(2).max(100).required(),
  role: Joi.string().valid('passenger', 'driver', 'union_admin').default('passenger')
});

const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().required()
});

const changePasswordSchema = Joi.object({
  currentPassword: Joi.string().required(),
  newPassword: Joi.string().min(6).required()
});

const forgotPasswordSchema = Joi.object({
  email: Joi.string().email().required()
});

const resetPasswordSchema = Joi.object({
  email: Joi.string().email().required(),
  otp: Joi.string().length(6).required(),
  newPassword: Joi.string().min(6).required()
});

/**
 * @route   POST /api/simple-auth/signup
 * @desc    Simple signup with email/password
 * @access  Public
 */
router.post('/signup', simpleAuthSignupLimiter, validate(signupSchema), signup);

/**
 * @route   POST /api/simple-auth/login
 * @desc    Simple login with email/password
 * @access  Public
 */
router.post('/login', simpleAuthLoginLimiter, validate(loginSchema), login);

/**
 * @route   POST /api/simple-auth/create-demo
 * @desc    Create demo accounts for testing
 * @access  Public in development only (never mounted in production)
 */
if (process.env.NODE_ENV !== 'production') {
  router.post('/create-demo', createDemoAccounts);
}

/**
 * @route   POST /api/simple-auth/change-password
 * @desc    Change password for email/password users
 * @access  Private
 */
router.post(
  '/change-password',
  authenticate,
  simpleAuthChangePasswordLimiter,
  validate(changePasswordSchema),
  changePassword
);

/**
 * @route   POST /api/simple-auth/forgot-password
 * @desc    Request password reset (send OTP to email)
 * @access  Public
 */
router.post(
  '/forgot-password',
  simpleAuthForgotPasswordLimiter,
  validate(forgotPasswordSchema),
  requestPasswordReset
);

/**
 * @route   POST /api/simple-auth/reset-password
 * @desc    Reset password using email + OTP
 * @access  Public
 */
router.post(
  '/reset-password',
  simpleAuthResetPasswordLimiter,
  validate(resetPasswordSchema),
  resetPassword
);

module.exports = router;
