const { otpSendIdentifierKey, otpVerifyIdentifierKey } = require('./otpRateLimitKeys');

function req(body, ip = '203.0.113.5') {
  return { body, ip };
}

describe('otpRateLimitKeys', () => {
  describe('otpSendIdentifierKey', () => {
    it('prefers normalized email when present', () => {
      expect(otpSendIdentifierKey(req({ email: '  Test@Example.COM ', phone: '919876543210' }))).toBe(
        'otp-send:email:test@example.com'
      );
    });

    it('uses last 10 digits of phone when no email', () => {
      expect(otpSendIdentifierKey(req({ phone: '+91 98765 43210' }, '1.2.3.4'))).toBe(
        'otp-send:phone:9876543210'
      );
    });

    it('falls back to IP when phone too short and no email', () => {
      expect(otpSendIdentifierKey(req({ phone: '12345' }, '10.0.0.1'))).toBe('otp-send:empty:10.0.0.1');
    });

    it('treats string without @ as non-email (phone path)', () => {
      expect(otpSendIdentifierKey(req({ email: 'not-an-email', phone: '9876543210' }))).toBe(
        'otp-send:phone:9876543210'
      );
    });
  });

  describe('otpVerifyIdentifierKey', () => {
    it('mirrors send key shape with otp-verify prefix', () => {
      expect(otpVerifyIdentifierKey(req({ email: 'a@b.co' }))).toBe('otp-verify:email:a@b.co');
      expect(otpVerifyIdentifierKey(req({ phone: '09876543210' }))).toBe('otp-verify:phone:9876543210');
      expect(otpVerifyIdentifierKey(req({}, '::1'))).toBe('otp-verify:empty:::1');
    });
  });
});
