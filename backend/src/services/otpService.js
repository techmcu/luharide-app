const crypto = require('crypto');
const { pool } = require('../config/database');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');
const { sendOTPEmail, isEmailConfigured } = require('./emailService');

const OTP_HMAC_KEY = process.env.OTP_HMAC_KEY || process.env.JWT_SECRET || '';
if (!OTP_HMAC_KEY && process.env.NODE_ENV === 'production') {
  throw new Error('OTP_HMAC_KEY or JWT_SECRET must be set in production');
}

const generateOTP = () => {
  return crypto.randomInt(100000, 1000000).toString();
};

function hmacOTP(otp) {
  return crypto.createHmac('sha256', OTP_HMAC_KEY).update(String(otp)).digest('hex');
}

// Single source of truth for how an email/phone is keyed. The INSERT, DELETE and
// verify queries MUST use the same normalized value — a past mismatch (DELETE on
// the raw email, INSERT on the lowercased one) left stale OTP rows behind and
// produced false "OTP expired" errors.
function normalizeEmail(email) {
  return String(email || '').toLowerCase().trim();
}
function normalizePhone(phone) {
  return String(phone || '').trim();
}

// Tunable without a redeploy via env. Expiry is always computed and compared on
// the DATABASE clock (NOW()), never Node's, so there is no app/DB clock skew or
// timezone drift regardless of whether the column is timestamp or timestamptz.
const OTP_TTL_MINUTES = Math.max(1, parseInt(process.env.OTP_TTL_MINUTES || '10', 10) || 10);
const OTP_MAX_ATTEMPTS = Math.max(1, parseInt(process.env.OTP_MAX_ATTEMPTS || '5', 10) || 5);

/**
 * Create and store OTP in database (phone)
 */
const createOTP = async (phone, purpose = 'login') => {
  const phoneNorm = normalizePhone(phone);
  try {
    const otp = generateOTP();
    const otpHash = hmacOTP(otp);

    await pool.query(
      'DELETE FROM otp_verifications WHERE phone = $1 AND is_verified = FALSE',
      [phoneNorm]
    );

    const result = await pool.query(
      `INSERT INTO otp_verifications (phone, otp, purpose, expires_at)
       VALUES ($1, $2, $3, NOW() + make_interval(mins => $4::int))
       RETURNING id, phone, purpose, expires_at`,
      [phoneNorm, otpHash, purpose, OTP_TTL_MINUTES]
    );

    logger.info(`OTP created for phone: ${phoneNorm}, purpose: ${purpose}`);

    return {
      id: result.rows[0].id,
      otp,
      phone: result.rows[0].phone,
      expiresAt: result.rows[0].expires_at
    };
  } catch (error) {
    logger.error('Error creating OTP:', { message: error.message, code: error.code, detail: error.detail });
    throw ApiError.internal('Failed to generate OTP');
  }
};

/**
 * Create and store OTP for email (email OTP flow)
 */
const createOTPByEmail = async (email, purpose = 'login') => {
  const emailNorm = normalizeEmail(email);
  try {
    const otp = generateOTP();
    const otpHash = hmacOTP(otp);

    // DELETE uses the SAME normalized key as the INSERT/verify — this is the fix
    // for stale rows that caused false "OTP expired" errors on a fresh code.
    await pool.query(
      'DELETE FROM otp_verifications WHERE email = $1 AND is_verified = FALSE',
      [emailNorm]
    );

    const result = await pool.query(
      `INSERT INTO otp_verifications (phone, email, otp, purpose, expires_at)
       VALUES (NULL, $1, $2, $3, NOW() + make_interval(mins => $4::int))
       RETURNING id, email, purpose, expires_at`,
      [emailNorm, otpHash, purpose, OTP_TTL_MINUTES]
    );

    logger.info(`OTP created for email: ${emailNorm}, purpose: ${purpose}`);

    return {
      id: result.rows[0].id,
      otp,
      email: result.rows[0].email,
      expiresAt: result.rows[0].expires_at
    };
  } catch (error) {
    logger.error('Error creating OTP by email:', { message: error.message, code: error.code, detail: error.detail });
    throw ApiError.internal('Failed to generate OTP');
  }
};

/**
 * Verify OTP (phone)
 */
const verifyOTP = async (phone, otp) => {
  const phoneNorm = normalizePhone(phone);
  const otpHash = hmacOTP(otp);

  const result = await pool.query(
    `UPDATE otp_verifications
     SET is_verified = TRUE, verified_at = NOW()
     WHERE id = (
       SELECT id FROM otp_verifications
       WHERE phone = $1 AND otp = $2 AND is_verified = FALSE
         AND expires_at > NOW() AND attempts < $3
       ORDER BY created_at DESC LIMIT 1
       FOR UPDATE SKIP LOCKED
     )
     RETURNING id, phone, purpose`,
    [phoneNorm, otpHash, OTP_MAX_ATTEMPTS]
  );

  if (result.rows.length > 0) {
    logger.info(`OTP verified for phone: ${phoneNorm}`);
    return { verified: true, phone: phoneNorm, purpose: result.rows[0].purpose };
  }

  // Expiry decided by the DB clock (is_expired), not Node — TZ/skew safe.
  const check = await pool.query(
    `SELECT id, attempts, (expires_at <= NOW()) AS is_expired FROM otp_verifications
     WHERE phone = $1 AND is_verified = FALSE
     ORDER BY created_at DESC LIMIT 1`,
    [phoneNorm]
  );

  if (check.rows.length === 0) {
    throw ApiError.badRequest('Invalid OTP');
  }

  const rec = check.rows[0];
  await pool.query(
    'UPDATE otp_verifications SET attempts = attempts + 1 WHERE id = $1',
    [rec.id]
  );

  if (rec.attempts >= OTP_MAX_ATTEMPTS) {
    throw ApiError.tooManyRequests('Too many failed attempts. Please request a new OTP');
  }
  if (rec.is_expired) {
    throw ApiError.badRequest('OTP has expired');
  }
  throw ApiError.badRequest('Invalid OTP');
};

/**
 * Verify OTP (email)
 */
const verifyOTPByEmail = async (email, otp) => {
  const emailNorm = normalizeEmail(email);
  const otpHash = hmacOTP(otp);

  const result = await pool.query(
    `UPDATE otp_verifications
     SET is_verified = TRUE, verified_at = NOW()
     WHERE id = (
       SELECT id FROM otp_verifications
       WHERE email = $1 AND otp = $2 AND is_verified = FALSE
         AND expires_at > NOW() AND attempts < $3
       ORDER BY created_at DESC LIMIT 1
       FOR UPDATE SKIP LOCKED
     )
     RETURNING id, email, purpose`,
    [emailNorm, otpHash, OTP_MAX_ATTEMPTS]
  );

  if (result.rows.length > 0) {
    logger.info(`OTP verified for email: ${emailNorm}`);
    return { verified: true, email: result.rows[0].email, purpose: result.rows[0].purpose };
  }

  // Expiry decided by the DB clock (is_expired), not Node — TZ/skew safe.
  const check = await pool.query(
    `SELECT id, attempts, (expires_at <= NOW()) AS is_expired FROM otp_verifications
     WHERE email = $1 AND is_verified = FALSE
     ORDER BY created_at DESC LIMIT 1`,
    [emailNorm]
  );

  if (check.rows.length === 0) {
    throw ApiError.badRequest('Invalid OTP');
  }

  const rec = check.rows[0];
  await pool.query(
    'UPDATE otp_verifications SET attempts = attempts + 1 WHERE id = $1',
    [rec.id]
  );

  if (rec.attempts >= OTP_MAX_ATTEMPTS) {
    throw ApiError.tooManyRequests('Too many failed attempts. Please request a new OTP');
  }
  if (rec.is_expired) {
    throw ApiError.badRequest('OTP has expired');
  }
  throw ApiError.badRequest('Invalid OTP');
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
