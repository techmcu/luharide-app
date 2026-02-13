const express = require('express');
const router = express.Router();
const Joi = require('joi');

const {
  signup,
  login,
  createDemoAccounts,
  changePassword
} = require('../controllers/simpleAuthController');

const { validate } = require('../middleware/validation');
const { authenticate } = require('../middleware/auth');

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

/**
 * @route   POST /api/simple-auth/signup
 * @desc    Simple signup with email/password
 * @access  Public
 */
router.post('/signup', validate(signupSchema), signup);

/**
 * @route   POST /api/simple-auth/login
 * @desc    Simple login with email/password
 * @access  Public
 */
router.post('/login', validate(loginSchema), login);

/**
 * @route   POST /api/simple-auth/create-demo
 * @desc    Create demo accounts for testing
 * @access  Public (should be protected in production)
 */
router.post('/create-demo', createDemoAccounts);

/**
 * @route   POST /api/simple-auth/change-password
 * @desc    Change password for email/password users
 * @access  Private
 */
router.post('/change-password', authenticate, validate(changePasswordSchema), changePassword);

module.exports = router;
