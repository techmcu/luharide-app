/**
 * Email service - Nodemailer + Gmail SMTP (or any SMTP)
 * Used for: OTP, notifications. No OTP logged in production.
 */
const nodemailer = require('nodemailer');
const logger = require('../config/logger');
const ApiError = require('../utils/ApiError');

let transporter = null;

function getTransporter() {
  if (transporter) return transporter;

  const user = process.env.EMAIL_USER || process.env.SMTP_USER;
  const pass = process.env.EMAIL_APP_PASSWORD || process.env.SMTP_PASSWORD;

  if (!user || !pass) {
    logger.warn('Email: EMAIL_USER / EMAIL_APP_PASSWORD not set. OTP emails will not be sent.');
    return null;
  }

  transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST || 'smtp.gmail.com',
    port: parseInt(process.env.SMTP_PORT || '587', 10),
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user, pass }
  });

  return transporter;
}

/**
 * Send a single email (HTML or plain text)
 * @param {string} to - Recipient email
 * @param {string} subject - Subject
 * @param {string} html - HTML body
 * @param {string} [text] - Plain text fallback
 */
async function sendEmail(to, subject, html, text = null) {
  const trans = getTransporter();
  if (!trans) {
    if (process.env.NODE_ENV === 'development') {
      logger.info(`[EMAIL DEV] Would send to ${to}: ${subject}`);
      return { sent: false, dev: true };
    }
    throw ApiError.internal('Email service not configured');
  }

  const from = process.env.EMAIL_FROM || process.env.EMAIL_USER || 'LuhaRide <noreply@luharide.com>';
  const mailOptions = {
    from,
    to,
    subject,
    html,
    text: text || html.replace(/<[^>]*>/g, '')
  };

  try {
    const info = await trans.sendMail(mailOptions);
    logger.info(`Email sent to ${to}: ${info.messageId}`);
    return { sent: true, messageId: info.messageId };
  } catch (err) {
    logger.error('Email send failed:', err.message);
    throw ApiError.internal('Failed to send email');
  }
}

/**
 * Send OTP email (6-digit). Never logs OTP in production.
 */
async function sendOTPEmail(to, otp) {
  const subject = 'Your LuhaRide verification code';
  const html = `
    <div style="font-family: sans-serif; max-width: 400px;">
      <h2>LuhaRide</h2>
      <p>Your verification code is:</p>
      <p style="font-size: 28px; font-weight: bold; letter-spacing: 4px;">${otp}</p>
      <p>Valid for 10 minutes. Do not share this code.</p>
      <p style="color: #666;">If you didn't request this, you can ignore this email.</p>
    </div>
  `;
  if (process.env.NODE_ENV !== 'development') {
    // Never log OTP in production
  } else {
    logger.info(`[DEV] OTP email for ${to}: ${otp}`);
  }
  return sendEmail(to, subject, html);
}

function isEmailConfigured() {
  const user = process.env.EMAIL_USER || process.env.SMTP_USER;
  const pass = process.env.EMAIL_APP_PASSWORD || process.env.SMTP_PASSWORD;
  return !!(user && pass);
}

module.exports = {
  sendEmail,
  sendOTPEmail,
  isEmailConfigured,
  getTransporter
};
