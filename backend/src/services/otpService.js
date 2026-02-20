const { pool } = require('../config/database');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');
const { sendOTPEmail, isEmailConfigured } = require('./emailService');

/**
 * Generate a random 6-digit OTP
 */
const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

/**
 * Create and store OTP in database (phone)
 */
const createOTP = async (phone, purpose = 'login') => {
  try {
    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await pool.query(
      'DELETE FROM otp_verifications WHERE phone = $1 AND is_verified = FALSE',
      [phone]
    );

    const result = await pool.query(
      `INSERT INTO otp_verifications (phone, otp, purpose, expires_at)
       VALUES ($1, $2, $3, $4)
       RETURNING id, phone, purpose, expires_at`,
      [phone, otp, purpose, expiresAt]
    );

    logger.info(`OTP created for phone: ${phone}, purpose: ${purpose}`);

    return {
      id: result.rows[0].id,
      otp,
      phone: result.rows[0].phone,
      expiresAt: result.rows[0].expires_at
    };
  } catch (error) {
    logger.error('Error creating OTP:', error);
    throw ApiError.internal('Failed to generate OTP');
  }
};

/**
 * Create and store OTP for email (email OTP flow)
 */
const createOTPByEmail = async (email, purpose = 'login') => {
  try {
    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Delete any existing unverified OTPs for this email
    await pool.query(
      'DELETE FROM otp_verifications WHERE email = $1 AND is_verified = FALSE',
      [email]
    );

    const result = await pool.query(
      `INSERT INTO otp_verifications (phone, email, otp, purpose, expires_at)
       VALUES (NULL, $1, $2, $3, $4)
       RETURNING id, email, purpose, expires_at`,
      [email.toLowerCase().trim(), otp, purpose, expiresAt]
    );

    logger.info(`OTP created for email: ${email}, purpose: ${purpose}`);

    return {
      id: result.rows[0].id,
      otp,
      email: result.rows[0].email,
      expiresAt: result.rows[0].expires_at
    };
  } catch (error) {
    logger.error('Error creating OTP by email:', error);
    throw ApiError.internal('Failed to generate OTP');
  }
};

/**
 * Verify OTP (phone)
 */
const verifyOTP = async (phone, otp) => {
  try {
    const result = await pool.query(
      `SELECT * FROM otp_verifications 
       WHERE phone = $1 AND otp = $2 AND is_verified = FALSE
       ORDER BY created_at DESC LIMIT 1`,
      [phone, otp]
    );

    if (result.rows.length === 0) {
      throw ApiError.badRequest('Invalid OTP');
    }

    const otpRecord = result.rows[0];
    if (new Date() > new Date(otpRecord.expires_at)) {
      throw ApiError.badRequest('OTP has expired');
    }
    if (otpRecord.attempts >= 5) {
      throw ApiError.tooManyRequests('Too many failed attempts. Please request a new OTP');
    }

    await pool.query(
      `UPDATE otp_verifications SET is_verified = TRUE, verified_at = CURRENT_TIMESTAMP WHERE id = $1`,
      [otpRecord.id]
    );

    logger.info(`OTP verified for phone: ${phone}`);
    return { verified: true, phone, purpose: otpRecord.purpose };
  } catch (error) {
    if (error instanceof ApiError && error.statusCode === 400) {
      await pool.query(
        `UPDATE otp_verifications SET attempts = attempts + 1 WHERE phone = $1 AND otp = $2 AND is_verified = FALSE`,
        [phone, otp]
      );
    }
    throw error;
  }
};

/**
 * Verify OTP (email)
 */
const verifyOTPByEmail = async (email, otp) => {
  try {
    const result = await pool.query(
      `SELECT * FROM otp_verifications 
       WHERE email = $1 AND otp = $2 AND is_verified = FALSE
       ORDER BY created_at DESC LIMIT 1`,
      [email.toLowerCase().trim(), otp]
    );

    if (result.rows.length === 0) {
      throw ApiError.badRequest('Invalid OTP');
    }

    const otpRecord = result.rows[0];
    if (new Date() > new Date(otpRecord.expires_at)) {
      throw ApiError.badRequest('OTP has expired');
    }
    if (otpRecord.attempts >= 5) {
      throw ApiError.tooManyRequests('Too many failed attempts. Please request a new OTP');
    }

    await pool.query(
      `UPDATE otp_verifications SET is_verified = TRUE, verified_at = CURRENT_TIMESTAMP WHERE id = $1`,
      [otpRecord.id]
    );

    logger.info(`OTP verified for email: ${email}`);
    return { verified: true, email: otpRecord.email, purpose: otpRecord.purpose };
  } catch (error) {
    if (error instanceof ApiError && error.statusCode === 400) {
      await pool.query(
        `UPDATE otp_verifications SET attempts = attempts + 1 WHERE email = $1 AND otp = $2 AND is_verified = FALSE`,
        [email, otp]
      );
    }
    throw error;
  }
};

/**
 * Send OTP via SMS (placeholder)
 */
const sendOTP = async (phone, otp) => {
  try {
    if (process.env.NODE_ENV === 'development') {
      logger.info(`[DEV] OTP for ${phone}: ${otp}`);
      console.log(`\n📱 OTP for ${phone}: ${otp}\n`);
      return { sent: true };
    }
    logger.info(`OTP sent to phone: ${phone}`);
    return { sent: true };
  } catch (error) {
    logger.error('Error sending OTP:', error);
    throw ApiError.internal('Failed to send OTP');
  }
};

/**
 * Send OTP via Email (Nodemailer / Gmail)
 */
const sendOTPByEmail = async (email, otp) => {
  if (!isEmailConfigured()) {
    if (process.env.NODE_ENV === 'development') {
      logger.info(`[DEV] Email OTP for ${email}: ${otp}`);
      console.log(`\n📧 OTP for ${email}: ${otp}\n`);
      return { sent: true, dev: true };
    }
    throw ApiError.serviceUnavailable('Email service not configured. Set EMAIL_USER and EMAIL_APP_PASSWORD on server.');
  }
  await sendOTPEmail(email, otp);
  return { sent: true };
};

/**
 * Clean up expired OTPs
 */
const cleanupExpiredOTPs = async () => {
  try {
    const result = await pool.query(
      'DELETE FROM otp_verifications WHERE expires_at < CURRENT_TIMESTAMP'
    );
    logger.info(`Cleaned up ${result.rowCount} expired OTPs`);
    return result.rowCount;
  } catch (error) {
    logger.error('Error cleaning up OTPs:', error);
  }
};

module.exports = {
  generateOTP,
  createOTP,
  verifyOTP,
  sendOTP,
  createOTPByEmail,
  verifyOTPByEmail,
  sendOTPByEmail,
  cleanupExpiredOTPs
};
