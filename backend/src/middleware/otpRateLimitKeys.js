/**
 * Pure key builders for OTP rate limits (unit-tested; used by rateLimiter).
 */

function otpSendIdentifierKey(req) {
  const b = req.body || {};
  const phone = String(b.phone || '').replace(/\D/g, '');
  const email = String(b.email || '').trim().toLowerCase();
  if (email && email.includes('@')) return `otp-send:email:${email}`;
  if (phone.length >= 10) return `otp-send:phone:${phone.slice(-10)}`;
  return `otp-send:empty:${req.ip}`;
}

function otpVerifyIdentifierKey(req) {
  const b = req.body || {};
  const phone = String(b.phone || '').replace(/\D/g, '');
  const email = String(b.email || '').trim().toLowerCase();
  if (email && email.includes('@')) return `otp-verify:email:${email}`;
  if (phone.length >= 10) return `otp-verify:phone:${phone.slice(-10)}`;
  return `otp-verify:empty:${req.ip}`;
}

module.exports = {
  otpSendIdentifierKey,
  otpVerifyIdentifierKey,
};
