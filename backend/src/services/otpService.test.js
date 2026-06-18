/**
 * otpService unit tests — OTP generation, storage, verification, email dispatch.
 * All DB calls and email service are mocked.
 */

jest.mock('../config/database', () => ({
  pool: { query: jest.fn() },
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));
jest.mock('./emailService', () => ({
  sendOTPEmail: jest.fn().mockResolvedValue({ sent: true }),
  isEmailConfigured: jest.fn().mockReturnValue(false),
}));

const { pool } = require('../config/database');
const { sendOTPEmail, isEmailConfigured } = require('./emailService');

const {
  generateOTP,
  createOTP,
  createOTPByEmail,
  verifyOTP,
  verifyOTPByEmail,
  sendOTP,
  sendOTPByEmail,
  cleanupExpiredOTPs,
} = require('./otpService');

const PHONE = '+919876543210';
const EMAIL = 'test@example.com';

beforeEach(() => {
  jest.clearAllMocks();
  pool.query.mockResolvedValue({ rows: [], rowCount: 0 });
});

// ── generateOTP ──────────────────────────────────────────────────────────────

describe('generateOTP', () => {
  it('returns a 6-digit string', () => {
    const otp = generateOTP();
    expect(otp).toMatch(/^\d{6}$/);
  });

  it('returns different values on successive calls (non-deterministic)', () => {
    const otps = new Set(Array.from({ length: 20 }, () => generateOTP()));
    // With 20 calls, extremely unlikely all are the same
    expect(otps.size).toBeGreaterThan(1);
  });
});

// ── createOTP (phone) ────────────────────────────────────────────────────────

describe('createOTP', () => {
  it('deletes old unverified OTPs and inserts a hashed OTP', async () => {
    const fakeRow = {
      id: 1,
      phone: PHONE,
      purpose: 'login',
      expires_at: new Date(Date.now() + 600000),
    };
    pool.query
      .mockResolvedValueOnce({ rows: [], rowCount: 0 }) // DELETE old
      .mockResolvedValueOnce({ rows: [fakeRow] }); // INSERT

    const result = await createOTP(PHONE, 'login');

    expect(result.otp).toMatch(/^\d{6}$/);
    expect(result.phone).toBe(PHONE);
    expect(result.id).toBe(1);

    // Verify the INSERT stores a hash, not the raw OTP
    const insertCall = pool.query.mock.calls[1];
    const storedOtp = insertCall[1][1]; // second param is the otp value
    expect(storedOtp).not.toBe(result.otp); // must be hashed
    expect(storedOtp).toHaveLength(64); // SHA-256 HMAC hex
  });

  it('throws ApiError on DB failure', async () => {
    pool.query.mockRejectedValueOnce(new Error('connection refused'));

    await expect(createOTP(PHONE)).rejects.toThrow('Failed to generate OTP');
  });
});

// ── createOTPByEmail ─────────────────────────────────────────────────────────

describe('createOTPByEmail', () => {
  it('stores hashed OTP for email and normalizes email to lowercase', async () => {
    const fakeRow = {
      id: 2,
      email: EMAIL,
      purpose: 'login',
      expires_at: new Date(Date.now() + 600000),
    };
    pool.query
      .mockResolvedValueOnce({ rows: [], rowCount: 0 }) // DELETE
      .mockResolvedValueOnce({ rows: [fakeRow] }); // INSERT

    const result = await createOTPByEmail('  Test@Example.COM  ');

    expect(result.otp).toMatch(/^\d{6}$/);
    expect(result.email).toBe(EMAIL);

    // DELETE and INSERT must use the SAME normalized email (the bug was DELETE on
    // the raw email + INSERT on the lowercased one → stale rows → false expiry).
    const deleteCall = pool.query.mock.calls[0];
    expect(deleteCall[1][0]).toBe('test@example.com');
    const insertCall = pool.query.mock.calls[1];
    expect(insertCall[1][0]).toBe('test@example.com');
  });
});

// ── verifyOTP (phone) ────────────────────────────────────────────────────────

describe('verifyOTP', () => {
  it('succeeds when OTP matches', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ id: 1, phone: PHONE, purpose: 'login' }],
    });

    const result = await verifyOTP(PHONE, '123456');
    expect(result.verified).toBe(true);
    expect(result.phone).toBe(PHONE);
  });

  it('throws "Invalid OTP" when no record exists', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [] }) // UPDATE found nothing
      .mockResolvedValueOnce({ rows: [] }); // check query also empty

    await expect(verifyOTP(PHONE, '000000')).rejects.toThrow('Invalid OTP');
  });

  it('throws "Too many failed attempts" when attempts >= 5', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [] }) // UPDATE found nothing
      .mockResolvedValueOnce({
        rows: [{ id: 10, attempts: 5, is_expired: false }],
      }) // check (expiry decided DB-side via is_expired)
      .mockResolvedValueOnce({ rowCount: 1 }); // increment attempts

    await expect(verifyOTP(PHONE, '000000')).rejects.toThrow('Too many failed attempts');
  });

  it('throws "OTP has expired" when DB reports is_expired', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({
        rows: [{ id: 10, attempts: 0, is_expired: true }],
      })
      .mockResolvedValueOnce({ rowCount: 1 });

    await expect(verifyOTP(PHONE, '000000')).rejects.toThrow('OTP has expired');
  });
});

// ── verifyOTPByEmail ─────────────────────────────────────────────────────────

describe('verifyOTPByEmail', () => {
  it('succeeds when OTP matches', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ id: 1, email: EMAIL, purpose: 'login' }],
    });

    const result = await verifyOTPByEmail(EMAIL, '123456');
    expect(result.verified).toBe(true);
    expect(result.email).toBe(EMAIL);
  });

  it('normalizes email before lookup', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ id: 1, email: EMAIL, purpose: 'login' }],
    });

    await verifyOTPByEmail('  Test@Example.COM  ', '123456');

    const queryCall = pool.query.mock.calls[0];
    expect(queryCall[1][0]).toBe('test@example.com');
  });

  it('throws "OTP has expired" when DB reports is_expired', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [] }) // UPDATE found nothing
      .mockResolvedValueOnce({ rows: [{ id: 7, attempts: 0, is_expired: true }] }) // check
      .mockResolvedValueOnce({ rowCount: 1 }); // increment

    await expect(verifyOTPByEmail(EMAIL, '000000')).rejects.toThrow('OTP has expired');
  });
});

// ── sendOTP (phone — placeholder) ───────────────────────────────────────────

describe('sendOTP', () => {
  const origEnv = process.env.NODE_ENV;
  afterEach(() => { process.env.NODE_ENV = origEnv; });

  it('returns sent: true in development', async () => {
    process.env.NODE_ENV = 'development';
    const result = await sendOTP(PHONE, '123456');
    expect(result.sent).toBe(true);
  });

  it('returns sent: true in production (placeholder)', async () => {
    process.env.NODE_ENV = 'production';
    const result = await sendOTP(PHONE, '123456');
    expect(result.sent).toBe(true);
  });
});

// ── sendOTPByEmail ───────────────────────────────────────────────────────────

describe('sendOTPByEmail', () => {
  const origEnv = process.env.NODE_ENV;
  afterEach(() => { process.env.NODE_ENV = origEnv; });

  it('calls emailService.sendOTPEmail when email is configured', async () => {
    isEmailConfigured.mockReturnValue(true);

    const result = await sendOTPByEmail(EMAIL, '654321');
    expect(sendOTPEmail).toHaveBeenCalledWith(EMAIL, '654321');
    expect(result.sent).toBe(true);
  });

  it('returns dev fallback when not configured in development', async () => {
    isEmailConfigured.mockReturnValue(false);
    process.env.NODE_ENV = 'development';

    const result = await sendOTPByEmail(EMAIL, '654321');
    expect(result.sent).toBe(true);
    expect(result.dev).toBe(true);
    expect(sendOTPEmail).not.toHaveBeenCalled();
  });

  it('throws serviceUnavailable when not configured in production', async () => {
    isEmailConfigured.mockReturnValue(false);
    process.env.NODE_ENV = 'production';

    await expect(sendOTPByEmail(EMAIL, '654321')).rejects.toThrow('Email service not configured');
  });
});

// ── cleanupExpiredOTPs ───────────────────────────────────────────────────────

describe('cleanupExpiredOTPs', () => {
  it('runs DELETE query and returns count', async () => {
    pool.query.mockResolvedValueOnce({ rowCount: 3 });

    const count = await cleanupExpiredOTPs();
    expect(count).toBe(3);
    expect(pool.query).toHaveBeenCalledWith(
      expect.stringContaining('DELETE FROM otp_verifications')
    );
  });

  it('handles DB errors without throwing', async () => {
    pool.query.mockRejectedValueOnce(new Error('DB down'));
    await expect(cleanupExpiredOTPs()).resolves.toBeUndefined();
  });
});
