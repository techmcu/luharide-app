const { pool } = require('../config/database');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');

/**
 * Generate a random 6-digit OTP
 */
const generateOTP = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

/**
 * Create and store OTP in database
 */
const createOTP = async (phone, purpose = 'login') => {
  try {
    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Delete any existing unverified OTPs for this phone
    await pool.query(
      'DELETE FROM otp_verifications WHERE phone = $1 AND is_verified = FALSE',
      [phone]
    );

    // Insert new OTP
    const result = await pool.query(
      `INSERT INTO otp_verifications (phone, otp, purpose, expires_at)
       VALUES ($1, $2, $3, $4)
       RETURNING id, phone, purpose, expires_at`,
      [phone, otp, purpose, expiresAt]
    );

    logger.info(`OTP created for phone: ${phone}, purpose: ${purpose}`);

    return {
      id: result.rows[0].id,
      otp, // In production, don't return OTP, only send via SMS
      phone: result.rows[0].phone,
      expiresAt: result.rows[0].expires_at
    };
  } catch (error) {
    logger.error('Error creating OTP:', error);
    throw ApiError.internal('Failed to generate OTP');
  }
};

/**
 * Verify OTP
 */
const verifyOTP = async (phone, otp) => {
  try {
    // Find the OTP
    const result = await pool.query(
      `SELECT * FROM otp_verifications 
       WHERE phone = $1 AND otp = $2 AND is_verified = FALSE
       ORDER BY created_at DESC
       LIMIT 1`,
      [phone, otp]
    );

    if (result.rows.length === 0) {
      throw ApiError.badRequest('Invalid OTP');
    }

    const otpRecord = result.rows[0];

    // Check if expired
    if (new Date() > new Date(otpRecord.expires_at)) {
      throw ApiError.badRequest('OTP has expired');
    }

    // Check attempts
    if (otpRecord.attempts >= 5) {
      throw ApiError.tooManyRequests('Too many failed attempts. Please request a new OTP');
    }

    // Mark as verified
    await pool.query(
      `UPDATE otp_verifications 
       SET is_verified = TRUE, verified_at = CURRENT_TIMESTAMP
       WHERE id = $1`,
      [otpRecord.id]
    );

    logger.info(`OTP verified successfully for phone: ${phone}`);

    return {
      verified: true,
      phone,
      purpose: otpRecord.purpose
    };
  } catch (error) {
    // Increment attempts on failed verification
    if (error instanceof ApiError && error.statusCode === 400) {
      await pool.query(
        `UPDATE otp_verifications 
         SET attempts = attempts + 1
         WHERE phone = $1 AND otp = $2 AND is_verified = FALSE`,
        [phone, otp]
      );
    }
    throw error;
  }
};

/**
 * Send OTP via SMS (placeholder - integrate with Twilio/other SMS provider)
 */
const sendOTP = async (phone, otp) => {
  try {
    // TODO: Integrate with SMS provider (Twilio, AWS SNS, etc.)
    // For development, just log the OTP
    if (process.env.NODE_ENV === 'development') {
      logger.info(`[DEV MODE] OTP for ${phone}: ${otp}`);
      console.log(`\n📱 OTP for ${phone}: ${otp}\n`);
      return { sent: true, message: 'OTP logged to console (dev mode)' };
    }

    // Production SMS sending logic
    // const twilioClient = require('twilio')(accountSid, authToken);
    // await twilioClient.messages.create({
    //   body: `Your LuhaRide OTP is: ${otp}. Valid for 10 minutes.`,
    //   from: process.env.TWILIO_PHONE,
    //   to: phone
    // });

    logger.info(`OTP sent to phone: ${phone}`);
    return { sent: true, message: 'OTP sent successfully' };
  } catch (error) {
    logger.error('Error sending OTP:', error);
    throw ApiError.internal('Failed to send OTP');
  }
};

/**
 * Clean up expired OTPs (run periodically)
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
  cleanupExpiredOTPs
};
