const Joi = require('joi');
const ApiError = require('../utils/ApiError');

/**
 * Validate request using Joi schema
 */
const validate = (schema) => {
  return (req, res, next) => {
    const validationOptions = {
      abortEarly: false, // Return all errors
      allowUnknown: true, // Ignore unknown props
      stripUnknown: true // Remove unknown props
    };

    // Validate req.body directly (not wrapped)
    const { error, value } = schema.validate(req.body, validationOptions);

    if (error) {
      const errorMessage = error.details
        .map(detail => detail.message)
        .join(', ');
      
      throw ApiError.badRequest(errorMessage);
    }

    // Replace request body with validated values
    req.body = value;

    next();
  };
};

/**
 * Common validation schemas
 */
const schemas = {
  // Phone validation
  phone: Joi.string()
    .pattern(/^[6-9]\d{9}$/)
    .required()
    .messages({
      'string.pattern.base': 'Phone number must be a valid 10-digit Indian number',
      'any.required': 'Phone number is required'
    }),

  // OTP validation
  otp: Joi.string()
    .length(6)
    .pattern(/^\d+$/)
    .required()
    .messages({
      'string.length': 'OTP must be 6 digits',
      'string.pattern.base': 'OTP must contain only numbers',
      'any.required': 'OTP is required'
    }),

  // Name validation
  name: Joi.string()
    .min(2)
    .max(100)
    .required()
    .messages({
      'string.min': 'Name must be at least 2 characters',
      'string.max': 'Name must not exceed 100 characters',
      'any.required': 'Name is required'
    }),

  // Email validation (optional)
  email: Joi.string()
    .email()
    .optional()
    .allow('', null)
    .messages({
      'string.email': 'Email must be valid'
    }),

  // Role validation
  role: Joi.string()
    .valid('passenger', 'driver', 'union_admin')
    .required()
    .messages({
      'any.only': 'Role must be passenger, driver, or union_admin',
      'any.required': 'Role is required'
    }),

  // ID validation
  id: Joi.number()
    .integer()
    .positive()
    .required()
    .messages({
      'number.base': 'ID must be a number',
      'number.positive': 'ID must be positive',
      'any.required': 'ID is required'
    })
};

module.exports = {
  validate,
  schemas
};
