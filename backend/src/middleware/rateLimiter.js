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
 * Admin bulk notifications — prevent notification spam.
 * 15 per hour per user (env: ADMIN_BULK_NOTIFY_MAX_PER_HOUR).
 */
const adminDashboardLimiter = rateLimit(
  withStore('admin-dashboard', {
    windowMs: 15 * 60 * 1000,
    max: parseLimitEnv('ADMIN_DASHBOARD_MAX_PER_15MIN', 60, 10, 200),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `admin-dash:user:${req.user.id}` : `admin-dash:ip:${req.ip}`,
    handler: () => {
      throw ApiError.tooManyRequests('Too many admin requests. Try again shortly.');
    },
  })
);

const adminBulkNotifyLimiter = rateLimit(
  withStore('admin-bulk-notify', {
    windowMs: 60 * 60 * 1000,
    max: parseLimitEnv('ADMIN_BULK_NOTIFY_MAX_PER_HOUR', 15, 1, 50),
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
 * Generic DB write operations — trip/booking/driver/route create, profile update, etc.
 * 20 per minute per user.
 */
const writeLimiter = rateLimit(
  withStore('write', {
    windowMs: 60 * 1000,
    max: parseLimitEnv('WRITE_MAX_PER_MINUTE', 20, 5, 60),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `write:user:${req.user.id}` : `write:ip:${req.ip}`,
    handler: () => {
      throw ApiError.tooManyRequests('Too many write requests. Wait a minute.');
    },
  })
);

/**
 * State transitions — start/complete/cancel trip, accept/reject booking, rating.
 * 15 per minute per user.
 */
const stateChangeLimiter = rateLimit(
  withStore('state-change', {
    windowMs: 60 * 1000,
    max: parseLimitEnv('STATE_CHANGE_MAX_PER_MINUTE', 15, 3, 40),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `state:user:${req.user.id}` : `state:ip:${req.ip}`,
    handler: () => {
      throw ApiError.tooManyRequests('Too many requests. Wait a minute.');
    },
  })
);

/**
 * Destructive operations — account/trip/driver/route delete.
 * 5 per minute per user.
 */
const destructiveLimiter = rateLimit(
  withStore('destructive', {
    windowMs: 60 * 1000,
    max: parseLimitEnv('DESTRUCTIVE_MAX_PER_MINUTE', 5, 1, 15),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `destroy:user:${req.user.id}` : `destroy:ip:${req.ip}`,
    handler: () => {
      throw ApiError.tooManyRequests('Too many delete requests. Wait a minute.');
    },
  })
);

/**
 * Refresh token — prevent token stuffing (per IP, no auth context).
 * 30 per minute per IP.
 */
const refreshTokenLimiter = rateLimit(
  withStore('refresh-token', {
    windowMs: 60 * 1000,
    max: parseLimitEnv('REFRESH_TOKEN_MAX_PER_MINUTE', 30, 5, 60),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    handler: () => {
      throw ApiError.tooManyRequests('Too many token refresh attempts. Wait a minute.');
    },
  })
);

/**
 * Union bulk schedule creation — multiple DB rows per request.
 * 10 per minute per user.
 */
const bulkWriteLimiter = rateLimit(
  withStore('bulk-write', {
    windowMs: 60 * 1000,
    max: parseLimitEnv('BULK_WRITE_MAX_PER_MINUTE', 10, 1, 30),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `bulk:user:${req.user.id}` : `bulk:ip:${req.ip}`,
    handler: () => {
      throw ApiError.tooManyRequests('Too many bulk operations. Wait a minute.');
    },
  })
);

/**
 * GET /api/trips/search — prevent search abuse / scraping.
 * 60 per minute per IP (generous for real users, blocks automated scraping).
 * Env: SEARCH_MAX_PER_MINUTE
 */
const searchLimiter = rateLimit(
  withStore('search', {
    windowMs: 60 * 1000,
    max: parseLimitEnv('SEARCH_MAX_PER_MINUTE', 60, 10, 200),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    handler: () => {
      throw ApiError.tooManyRequests('Too many search requests. Please wait a moment.');
    },
  })
);

/**
 * POST /api/simple-auth/google — Google Sign-In (per IP).
 * 10 attempts per 5 minutes; only failed requests count.
 */
const googleSignInLimiter = rateLimit(
  withStore('google-signin', {
    windowMs: 5 * 60 * 1000,
    max: parseLimitEnv('GOOGLE_SIGNIN_MAX', 10, 3, 30),
    skipSuccessfulRequests: true,
    standardHeaders: true,
    legacyHeaders: false,
    handler: () => {
      throw ApiError.tooManyRequests('Too many Google sign-in attempts. Try again in 5 minutes.');
    },
  })
);

/**
 * Profile update — 10 per hour per user.
 */
const profileUpdateLimiter = rateLimit(
  withStore('profile-update', {
    windowMs: 60 * 60 * 1000,
    max: parseLimitEnv('PROFILE_UPDATE_MAX_PER_HOUR', 10, 2, 30),
    skipSuccessfulRequests: false,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) =>
      req.user && req.user.id ? `profile:user:${req.user.id}` : `profile:ip:${req.ip}`,
    handler: () => {
      const err = ApiError.tooManyRequests('Profile update limit reached. Try again later.');
      err.errorCode = 'PROFILE_RATE_LIMIT';
      throw err;
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
  googleSignInLimiter,
  searchLimiter,
  adminDashboardLimiter,
  adminBulkNotifyLimiter,
  writeLimiter,
  stateChangeLimiter,
  destructiveLimiter,
  refreshTokenLimiter,
  bulkWriteLimiter,
  profileUpdateLimiter,
};
