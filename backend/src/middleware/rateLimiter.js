/** Per-IP limits use req.ip — enable real client IP via TRUST_PROXY (see src/config/trustProxy.js). */
const rateLimit = require('express-rate-limit');
const ApiError = require('../utils/ApiError');
const { createRateLimitRedisStore } = require('../config/redis');
const { otpSendIdentifierKey, otpVerifyIdentifierKey } = require('./otpRateLimitKeys');
const { parseLimitEnv } = require('./parseLimitEnv');

/** Optional Redis-backed store (multi-process / multi-node); else in-memory */
function withStore(name, opts) {
  const store = createRateLimitRedisStore(name);
  return store ? { ...opts, store } : opts;
}

/**
 * Global /api limit — counts ALL routes under /api (search, trips, login, etc.).
 * Default raised from 100→500 per 15min: 100 was easy to hit during normal app use
 * (and behind nginx without trust proxy, every user shared ONE bucket).
 *
 * Env: API_RATE_LIMIT_MAX (or legacy RATE_LIMIT_MAX_REQUESTS), API_RATE_LIMIT_WINDOW_MS
 */
const _apiWindow = parseInt(
  process.env.API_RATE_LIMIT_WINDOW_MS || process.env.RATE_LIMIT_WINDOW_MS || String(15 * 60 * 1000),
  10
);
const _apiMax = parseInt(
  process.env.API_RATE_LIMIT_MAX || process.env.RATE_LIMIT_MAX_REQUESTS || '500',
  10
);

const apiLimiter = rateLimit(
  withStore('api', {
    windowMs: Number.isFinite(_apiWindow) && _apiWindow > 0 ? _apiWindow : 15 * 60 * 1000,
    max: Number.isFinite(_apiMax) && _apiMax > 0 ? _apiMax : 500,
    message: 'Too many requests from this IP, please try again later',
    standardHeaders: true,
    legacyHeaders: false,
    skip: (req) =>
      req.method === 'OPTIONS' ||
      req.path === '/health' ||
      req.path === '/api/health' ||
      (typeof req.originalUrl === 'string' && req.originalUrl.split('?')[0].endsWith('/health')),
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many requests, please try again later');
    },
  })
);

/**
 * Auth endpoints rate limiter (stricter)
 */
const authLimiter = rateLimit(
  withStore('auth-legacy', {
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // Limit each IP to 5 requests per windowMs
    skipSuccessfulRequests: true,
    message: 'Too many authentication attempts, please try again later',
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many login attempts, please try again after 15 minutes');
    },
  })
);

/**
 * OTP rate limiter (very strict)
 */
const otpLimiter = rateLimit(
  withStore('otp', {
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 3, // Limit each IP to 3 OTP requests per hour
    skipSuccessfulRequests: false,
    message: 'Too many OTP requests, please try again later',
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many OTP requests, please try again after 1 hour');
    },
  })
);

const _otpSendIdentWindow = parseInt(
  process.env.OTP_SEND_IDENT_WINDOW_MS || String(60 * 60 * 1000),
  10
);

const otpSendIdentifierLimiter = rateLimit(
  withStore('otp-send-ident', {
    windowMs: Number.isFinite(_otpSendIdentWindow) && _otpSendIdentWindow > 0 ? _otpSendIdentWindow : 60 * 60 * 1000,
    max: parseLimitEnv('OTP_SEND_IDENTIFIER_MAX', 3, 1, 30),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => otpSendIdentifierKey(req),
    message: 'Too many OTP requests for this phone or email',
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many OTP requests for this number or email. Try again later.');
    },
  })
);

const otpVerifyIdentifierLimiter = rateLimit(
  withStore('otp-verify-ident', {
    windowMs: 15 * 60 * 1000,
    max: parseLimitEnv('OTP_VERIFY_IDENTIFIER_MAX', 8, 3, 40),
    skipSuccessfulRequests: true,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => otpVerifyIdentifierKey(req),
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many incorrect OTP attempts for this number or email. Try again later.');
    },
  })
);

/**
 * Authenticated document uploads (per user).
 */
const uploadDocLimiter = rateLimit(
  withStore('upload-doc', {
    windowMs: 60 * 60 * 1000,
    max: parseLimitEnv('UPLOAD_DOC_MAX_PER_HOUR', 30, 5, 500),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `upload-doc:user:${req.user.id}` : `upload-doc:ip:${req.ip}`,
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many uploads. Try again in an hour.');
    },
  })
);

/**
 * Union PDF poster generation (CPU-heavy).
 */
const unionPosterLimiter = rateLimit(
  withStore('union-poster', {
    windowMs: 60 * 1000,
    max: parseLimitEnv('UNION_POSTER_MAX_PER_MINUTE', 15, 3, 120),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `union-poster:user:${req.user.id}` : `union-poster:ip:${req.ip}`,
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many poster downloads. Please wait a minute.');
    },
  })
);

/**
 * Cancel ride/schedule spam protection.
 * This endpoint can be hit repeatedly by accidental double taps / poor networks.
 */
const cancelScheduleLimiter = rateLimit(
  withStore('cancel-schedule', {
    windowMs: 10 * 1000, // 10 seconds
    max: 5, // allow small burst only
    message: 'Too many cancel requests, please try again later',
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many cancel requests. Please try again in a few seconds.');
    },
  })
);

/**
 * POST /api/simple-auth/login — credential stuffing / brute force (per IP).
 * Env: SIMPLE_AUTH_LOGIN_MAX (default 15 per 15 min). Only failed attempts count.
 */
const simpleAuthLoginLimiter = rateLimit(
  withStore('simple-login', {
    windowMs: 15 * 60 * 1000,
    max: parseLimitEnv('SIMPLE_AUTH_LOGIN_MAX', 15, 5, 60),
    skipSuccessfulRequests: true,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many failed login attempts. Try again in 15 minutes.');
    },
  })
);

/**
 * POST /api/simple-auth/signup — spam account creation (per IP).
 * Env: SIMPLE_AUTH_SIGNUP_MAX (default 10 per hour)
 */
const simpleAuthSignupLimiter = rateLimit(
  withStore('simple-signup', {
    windowMs: 60 * 60 * 1000,
    max: parseLimitEnv('SIMPLE_AUTH_SIGNUP_MAX', 10, 3, 100),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many signup attempts from this network. Try again in 1 hour.');
    },
  })
);

/**
 * POST /api/simple-auth/forgot-password — email / SMTP abuse (per IP).
 * Env: SIMPLE_AUTH_FORGOT_MAX (default 5 per hour)
 */
const simpleAuthForgotPasswordLimiter = rateLimit(
  withStore('simple-forgot', {
    windowMs: 60 * 60 * 1000,
    max: parseLimitEnv('SIMPLE_AUTH_FORGOT_MAX', 5, 2, 30),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many password reset requests. Try again in 1 hour.');
    },
  })
);

/**
 * POST /api/simple-auth/reset-password — OTP guess / spam (per IP).
 * Env: SIMPLE_AUTH_RESET_MAX (default 12 per 15 min). Only failed attempts count.
 */
const simpleAuthResetPasswordLimiter = rateLimit(
  withStore('simple-reset', {
    windowMs: 15 * 60 * 1000,
    max: parseLimitEnv('SIMPLE_AUTH_RESET_MAX', 12, 5, 60),
    skipSuccessfulRequests: true,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many reset attempts. Try again in 15 minutes.');
    },
  })
);

/**
 * POST /api/simple-auth/change-password (authenticated) — still cap abuse.
 * Env: SIMPLE_AUTH_CHANGE_PASSWORD_MAX (default 10 per hour)
 */
const simpleAuthChangePasswordLimiter = rateLimit(
  withStore('simple-change-pw', {
    windowMs: 60 * 60 * 1000,
    max: parseLimitEnv('SIMPLE_AUTH_CHANGE_PASSWORD_MAX', 10, 3, 50),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      throw ApiError.tooManyRequests('Too many password change attempts. Try again in 1 hour.');
    },
  })
);

/**
 * Admin poster OCR — CPU-heavy, limit strictly.
 * 5 per minute per user.
 */
const adminPosterLimiter = rateLimit(
  withStore('admin-poster', {
    windowMs: 60 * 1000,
    max: parseLimitEnv('ADMIN_POSTER_MAX_PER_MINUTE', 5, 1, 15),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `admin-poster:user:${req.user.id}` : `admin-poster:ip:${req.ip}`,
    handler: () => {
      throw ApiError.tooManyRequests('Too many poster uploads. Wait a minute.');
    },
  })
);

/**
 * Admin bulk notifications — prevent notification spam.
 * 5 per hour per user.
 */
const adminBulkNotifyLimiter = rateLimit(
  withStore('admin-bulk-notify', {
    windowMs: 60 * 60 * 1000,
    max: parseLimitEnv('ADMIN_BULK_NOTIFY_MAX_PER_HOUR', 5, 1, 20),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `admin-bulk-notify:user:${req.user.id}` : `admin-bulk-notify:ip:${req.ip}`,
    handler: () => {
      throw ApiError.tooManyRequests('Too many bulk notifications. Try again in an hour.');
    },
  })
);

/**
 * Admin ride creation — prevent DB spam.
 * 10 per minute per user.
 */
const adminRideCreateLimiter = rateLimit(
  withStore('admin-ride-create', {
    windowMs: 60 * 1000,
    max: parseLimitEnv('ADMIN_RIDE_CREATE_MAX_PER_MINUTE', 10, 1, 30),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `admin-ride:user:${req.user.id}` : `admin-ride:ip:${req.ip}`,
    handler: () => {
      throw ApiError.tooManyRequests('Too many ride creations. Wait a minute.');
    },
  })
);

module.exports = {
  apiLimiter,
  authLimiter,
  otpLimiter,
  otpSendIdentifierLimiter,
  otpVerifyIdentifierLimiter,
  uploadDocLimiter,
  unionPosterLimiter,
  cancelScheduleLimiter,
  simpleAuthLoginLimiter,
  simpleAuthSignupLimiter,
  simpleAuthForgotPasswordLimiter,
  simpleAuthResetPasswordLimiter,
  simpleAuthChangePasswordLimiter,
  adminPosterLimiter,
  adminBulkNotifyLimiter,
  adminRideCreateLimiter,
};
