/**
 * Simple auth — signup, login, password change, password reset
 * SOP: P-001→002, P-006, P-010→012, P-018
 * DB, bcrypt, token, and OTP services are mocked — no real database connection.
 */

jest.mock('../config/database', () => ({
  pool: { query: jest.fn() },
}));
jest.mock('../services/tokenService', () => ({
  generateTokenPair: jest.fn().mockResolvedValue({
    accessToken: 'at-mock', refreshToken: 'rt-mock',
  }),
  revokeAllUserTokens: jest.fn().mockResolvedValue(0),
}));
jest.mock('../services/otpService', () => ({
  createOTPByEmail: jest.fn().mockResolvedValue({ otp: '123456' }),
  verifyOTPByEmail: jest.fn().mockResolvedValue({ verified: true, purpose: 'password_reset' }),
  sendOTPByEmail: jest.fn().mockResolvedValue(),
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const bcrypt = require('bcryptjs');
const { pool } = require('../config/database');
const {
  signup, login, changePassword, requestPasswordReset, resetPassword,
} = require('./simpleAuthController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const USER_ID = 'c0000000-0000-0000-0000-000000000001';

const userRow = {
  id: USER_ID,
  name: 'Test User',
  email: 'test@example.com',
  role: 'passenger',
  is_verified: true,
  is_active: true,
  password_hash: '$2a$12$fakehashedpassword',
  driver_verification_status: 'none',
  driver_kyc_reupload_allowed: false,
  driver_code: null,
  failed_login_attempts: 0,
  locked_until: null,
};

// ── SOP P-001: Signup ────────────────────────────────────────────────────────
describe('signup', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(bcrypt, 'hash').mockResolvedValue('$2a$12$hashedpw');
  });

  it('creates new user and returns tokens', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ ...userRow, id: USER_ID }],
    });

    const req = {
      body: { email: 'new@example.com', password: 'Test1234!', name: 'New User' },
      headers: { 'user-agent': 'test' }, ip: '127.0.0.1',
    };
    const res = mockRes();
    signup(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.tokens.accessToken).toBe('at-mock');
  });

  // ── SOP P-010: Duplicate email ─────────────────────────────────────────────
  it('rejects duplicate email', async () => {
    const err = new Error('duplicate');
    err.code = '23505';
    err.constraint = 'users_email_key';
    pool.query.mockRejectedValueOnce(err);

    const req = {
      body: { email: 'existing@example.com', password: 'Test1234!', name: 'Dup User' },
      headers: { 'user-agent': 'test' }, ip: '127.0.0.1',
    };
    const next = jest.fn();
    signup(req, res = mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 409 }));
  });
});

// ── SOP P-002: Login ─────────────────────────────────────────────────────────
describe('login', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(true);
  });

  it('logs in with correct credentials', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [userRow] })         // SELECT user
      .mockResolvedValueOnce({ rows: [] })                 // UPDATE last_login
      .mockResolvedValueOnce({ rows: [] });                // INSERT login_history

    const req = {
      body: { email: 'test@example.com', password: 'Test1234!' },
      headers: { 'user-agent': 'test' }, ip: '127.0.0.1',
    };
    const res = mockRes();
    login(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.user.email).toBe('test@example.com');
  });

  // ── SOP P-011: Wrong password ──────────────────────────────────────────────
  it('rejects wrong password', async () => {
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(false);

    pool.query
      .mockResolvedValueOnce({ rows: [userRow] })   // SELECT user
      .mockResolvedValueOnce({ rows: [] });          // UPDATE failed_login_attempts

    const req = {
      body: { email: 'test@example.com', password: 'wrong' },
      headers: { 'user-agent': 'test' }, ip: '127.0.0.1',
    };
    const next = jest.fn();
    login(req, res = mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401 }));
  });

  // ── SOP P-012: Non-existent email ──────────────────────────────────────────
  it('rejects non-existent email', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] }); // SELECT — empty

    const req = {
      body: { email: 'nobody@example.com', password: 'Test1234!' },
      headers: { 'user-agent': 'test' }, ip: '127.0.0.1',
    };
    const next = jest.fn();
    login(req, res = mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401 }));
  });

  // ── Account lockout after 10 failed attempts ──────────────────────────────
  it('locks account after 10 failed attempts', async () => {
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(false);

    pool.query
      .mockResolvedValueOnce({ rows: [{ ...userRow, failed_login_attempts: 9 }] })
      .mockResolvedValueOnce({ rows: [] }); // UPDATE with locked_until

    const req = {
      body: { email: 'test@example.com', password: 'wrong' },
      headers: { 'user-agent': 'test' }, ip: '127.0.0.1',
    };
    const next = jest.fn();
    login(req, res = mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 429 }));
  });

  // ── Locked account rejects login ──────────────────────────────────────────
  it('rejects login for locked account', async () => {
    const lockedUntil = new Date(Date.now() + 30 * 60 * 1000).toISOString();
    pool.query.mockResolvedValueOnce({
      rows: [{ ...userRow, locked_until: lockedUntil }],
    });

    const req = {
      body: { email: 'test@example.com', password: 'Test1234!' },
      headers: { 'user-agent': 'test' }, ip: '127.0.0.1',
    };
    const next = jest.fn();
    login(req, res = mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 429 }));
  });

  // ── Inactive account ──────────────────────────────────────────────────────
  it('rejects inactive account', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ ...userRow, is_active: false }],
    });

    const req = {
      body: { email: 'test@example.com', password: 'Test1234!' },
      headers: { 'user-agent': 'test' }, ip: '127.0.0.1',
    };
    const next = jest.fn();
    login(req, res = mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
  });
});

// ── SOP P-006: Change password ───────────────────────────────────────────────
describe('changePassword', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(true);
    jest.spyOn(bcrypt, 'hash').mockResolvedValue('$2a$12$newhash');
  });

  it('changes password with correct current password', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ password_hash: '$2a$12$old' }] })  // SELECT
      .mockResolvedValueOnce({ rows: [] });                                 // UPDATE

    const req = {
      body: { currentPassword: 'old', newPassword: 'NewPass123!' },
      user: { id: USER_ID },
    };
    const res = mockRes();
    changePassword(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
  });

  it('rejects wrong current password', async () => {
    jest.spyOn(bcrypt, 'compare').mockResolvedValue(false);
    pool.query.mockResolvedValueOnce({ rows: [{ password_hash: '$2a$12$old' }] });

    const req = {
      body: { currentPassword: 'wrong', newPassword: 'NewPass123!' },
      user: { id: USER_ID },
    };
    const next = jest.fn();
    changePassword(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects missing new password', async () => {
    const req = { body: {}, user: { id: USER_ID } };
    const next = jest.fn();
    changePassword(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });
});

// ── SOP P-018: Forgot / reset password ───────────────────────────────────────
describe('requestPasswordReset', () => {
  beforeEach(() => jest.clearAllMocks());

  it('sends OTP for existing email (no user enumeration)', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: USER_ID }] }); // user exists

    const req = { body: { email: 'test@example.com' } };
    const res = mockRes();
    requestPasswordReset(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.message).toContain('OTP has been sent');
  });

  it('responds success even for non-existent email (no enumeration)', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] }); // no user

    const req = { body: { email: 'nobody@example.com' } };
    const res = mockRes();
    requestPasswordReset(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.message).toContain('OTP has been sent');
  });
});

describe('resetPassword', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    jest.spyOn(bcrypt, 'hash').mockResolvedValue('$2a$12$resethash');
  });

  it('resets password with valid OTP', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: USER_ID }] })   // SELECT user
      .mockResolvedValueOnce({ rows: [] });                   // UPDATE password

    const req = { body: { email: 'test@example.com', otp: '123456', newPassword: 'Reset123!' } };
    const res = mockRes();
    resetPassword(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
  });
});
