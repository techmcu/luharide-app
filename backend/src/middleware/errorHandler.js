const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');
const { applyCorsHeadersOnError } = require('./corsLuha');

/**
 * Convert error to ApiError if needed (preserve PostgreSQL err.code for handler)
 */
const errorConverter = (err, req, res, next) => {
  let error = err;
  
  if (!(error instanceof ApiError)) {
    const statusCode = error.statusCode || error.status || 500;
    const message = error.message || 'Internal Server Error';
    error = new ApiError(statusCode, message, false, err.stack);
    if (err.code) error.code = err.code; // preserve PG/DB error code for errorHandler
  }
  
  next(error);
};

/**
 * Error handler middleware
 */
const errorHandler = (err, req, res, next) => {
  // Ensure CORS headers are present even on error responses.
  applyCorsHeadersOnError(req, res);

  let { statusCode, message } = err;
  let errors = err.errors || null;

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    statusCode = 401;
    message = 'Invalid token';
  }

  if (err.name === 'TokenExpiredError') {
    statusCode = 401;
    message = 'Token expired';
  }

  // Validation errors
  if (err.name === 'ValidationError') {
    statusCode = 400;
    message = 'Validation error';
  }

  // Database errors
  if (err.code === '23505') { // Unique violation
    statusCode = 409;
    message = 'Resource already exists';
  }

  if (err.code === '23503') { // Foreign key violation
    statusCode = 400;
    message = 'Invalid reference';
  }

  if (err.code === '23502') { // Not null violation
    statusCode = 400;
    message = message || 'Missing required data';
  }

  if (err.code === '42P01') { // Undefined table
    statusCode = 503;
    message = 'Database schema outdated. Run migrations (npm run migrate).';
  }

  if (err.code === '42703') { // Undefined column
    statusCode = 503;
    message = message || 'Database schema outdated. Run migrations (npm run migrate).';
  }

  // Any other PostgreSQL constraint / schema errors -> 400 or 503, keep message
  if (err.code && String(err.code).match(/^23/)) {
    statusCode = statusCode === 500 ? 400 : statusCode;
    message = message || 'Invalid or duplicate data.';
  }
  if (err.code && String(err.code).match(/^42/)) {
    statusCode = 503;
    message = message || 'Database schema error. Run migrations (npm run migrate).';
  }
  
  // Log error
  if (err.isOperational) {
    logger.warn({
      statusCode,
      message,
      requestId: req.id,
      url: req.originalUrl,
      method: req.method,
      ip: req.ip,
      userId: req.user?.id
    });
  } else {
    logger.error({
      statusCode,
      message,
      stack: err.stack,
      requestId: req.id,
      url: req.originalUrl,
      method: req.method,
      ip: req.ip,
      userId: req.user?.id
    });
  }
  
  const isProd = process.env.NODE_ENV === 'production';
  // In production, hide internal 5xx details from clients.
  const finalMessage = (statusCode >= 500 && isProd)
    ? 'Something went wrong. Please try again later.'
    : ((statusCode === 500 && err.message && err.message !== 'Internal Server Error')
        ? err.message
        : message);

  // Send error response
  const response = {
    success: false,
    message: finalMessage,
    ...(errors && { errors }),
    ...(process.env.NODE_ENV === 'development' && { 
      stack: err.stack
    })
  };
  
  res.status(statusCode).json(response);
};

module.exports = { errorConverter, errorHandler };
