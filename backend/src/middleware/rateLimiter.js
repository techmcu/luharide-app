const rateLimit = require('express-rate-limit');
const ApiError = require('../utils/ApiError');

/**
 * General API rate limiter
 */
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => req.path === '/health' || req.path === '/api/health',
  handler: (req, res) => {
    throw ApiError.tooManyRequests('Too many requests, please try again later');
  }
});

/**
 * Auth endpoints rate limiter (stricter)
 */
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 requests per windowMs
  skipSuccessfulRequests: true,
  message: 'Too many authentication attempts, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    throw ApiError.tooManyRequests('Too many login attempts, please try again after 15 minutes');
  }
});

/**
 * OTP rate limiter (very strict)
 */
const otpLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3, // Limit each IP to 3 OTP requests per hour
  skipSuccessfulRequests: false,
  message: 'Too many OTP requests, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    throw ApiError.tooManyRequests('Too many OTP requests, please try again after 1 hour');
  }
});

/**
 * Cancel ride/schedule spam protection.
 * This endpoint can be hit repeatedly by accidental double taps / poor networks.
 */
const cancelScheduleLimiter = rateLimit({
  windowMs: 10 * 1000, // 10 seconds
  max: 5, // allow small burst only
  message: 'Too many cancel requests, please try again later',
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    throw ApiError.tooManyRequests('Too many cancel requests. Please try again in a few seconds.');
  }
});

module.exports = {
  apiLimiter,
  authLimiter,
  otpLimiter,
  cancelScheduleLimiter
};
