/**
 * Auth flow integration tests.
 * Mounts real Express routes via sharedApp + supertest.
 * DB and token service are mocked — no real database needed.
 */

const request = require('supertest');
const bcrypt = require('bcryptjs');

// ── Mocks (before any require that touches them) ─────────────────────────────

jest.mock('../../src/config/database', () => ({
  pool: { query: jest.fn(), connect: jest.fn() },
}));

jest.mock('../../src/services/tokenService', () => ({
  generateTokenPair: jest.fn().mockResolvedValue({
    accessToken: 'mock-access-token',
    refreshToken: 'mock-refresh-token',
  }),
  verifyRefreshToken: jest.fn(),
  revokeRefreshToken: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../../src/services/otpService', () => ({
  createOTP: jest.fn(),
  verifyOTP: jest.fn(),
  sendOTP: jest.fn(),
  createOTPByEmail: jest.fn(),
  verifyOTPByEmail: jest.fn(),
  sendOTPByEmail: jest.fn(),
}));

jest.mock('../../src/config/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
}));

const { pool } = require('../../src/config/database');
const tokenService = require('../../src/services/tokenService');
const { createBaseApp, attachErrorHandlers } = require('../../microservices/sharedApp');
const simpleAuthRoutes = require('../../src/routes/simpleAuth');

// ── App setup ────────────────────────────────────────────────────────────────

let app;
beforeAll(() => {
  app = createBaseApp('test-auth');
  app.use('/api/simple-auth', simpleAuthRoutes);
  attachErrorHandlers(app);
});

beforeEach(() => {
  jest.clearAllMocks();
});

// ── Helpers ──────────────────────────────────────────────────────────────────

const HASH = bcrypt.hashSync('Test1234', 10);

const mockUser = (overrides = {}) => ({
  id: 'user-1',
  name: 'Test User',
  email: 'test@example.com',
  role: 'passenger',
  password_hash: HASH,
  is_verified: true,
  is_active: true,
  driver_verification_status: 'none',
  driver_kyc_reupload_allowed: false,
  driver_code: null,
  ...overrides,
});

// ─────────────────────────────────────────────────────────────────────────────
// SIGNUP
// ─────────────────────────────────────────────────────────────────────────────

describe('POST /api/simple-auth/signup', () => {
  it('creates user and returns tokens', async () => {
    const user = mockUser();
    pool.query
      .mockResolvedValueOnce({ rows: [user] });      // INSERT new user

    const res = await request(app)
      .post('/api/simple-auth/signup')
      .send({ email: 'test@example.com', password: 'Test1234', name: 'Test User' });

    expect(res.status).toBe(201);
    expect(res.body.data.tokens.accessToken).toBe('mock-access-token');
    expect(res.body.data.user.email).toBe('test@example.com');
    expect(tokenService.generateTokenPair).toHaveBeenCalledTimes(1);
  });

  it('rejects duplicate email with 409', async () => {
    const err = new Error('duplicate key value violates unique constraint');
    err.code = '23505';
    err.constraint = 'idx_users_email_unique';
    pool.query.mockRejectedValueOnce(err);

    const res = await request(app)
      .post('/api/simple-auth/signup')
      .send({ email: 'test@example.com', password: 'Test1234', name: 'Test User' });

    expect(res.status).toBe(409);
    expect(res.body.message).toMatch(/already exists/i);
  });

  it('rejects missing fields with 400 (validation)', async () => {
    const res = await request(app)
      .post('/api/simple-auth/signup')
      .send({ email: 'test@example.com' });

    expect(res.status).toBe(400);
  });

  it('rejects invalid email with 400', async () => {
    const res = await request(app)
      .post('/api/simple-auth/signup')
      .send({ email: 'not-an-email', password: 'Test1234', name: 'Test' });

    expect(res.status).toBe(400);
  });

  it('rejects short password with 400', async () => {
    const res = await request(app)
      .post('/api/simple-auth/signup')
      .send({ email: 'test@example.com', password: '12', name: 'Test' });

    expect(res.status).toBe(400);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN
// ─────────────────────────────────────────────────────────────────────────────

describe('POST /api/simple-auth/login', () => {
  it('returns tokens for valid credentials', async () => {
    const user = mockUser();
    pool.query
      .mockResolvedValueOnce({ rows: [user] })       // SELECT user
      .mockResolvedValueOnce({ rows: [] })            // UPDATE last_login
      .mockResolvedValueOnce({ rows: [] });           // INSERT login_history

    const res = await request(app)
      .post('/api/simple-auth/login')
      .send({ email: 'test@example.com', password: 'Test1234' });

    expect(res.status).toBe(200);
    expect(res.body.data.tokens.accessToken).toBe('mock-access-token');
    expect(res.body.data.user.id).toBe('user-1');
  });

  it('returns 401 for wrong password (no user enumeration)', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [mockUser()] })   // SELECT user
      .mockResolvedValueOnce({ rowCount: 1 });          // UPDATE failed_login_attempts

    const res = await request(app)
      .post('/api/simple-auth/login')
      .send({ email: 'test@example.com', password: 'WrongPassword' });

    expect(res.status).toBe(401);
    expect(res.body.message).toBe('Invalid email or password');
  });

  it('returns 401 for non-existent email (same error message)', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const res = await request(app)
      .post('/api/simple-auth/login')
      .send({ email: 'nobody@example.com', password: 'Test1234' });

    expect(res.status).toBe(401);
    expect(res.body.message).toBe('Invalid email or password');
  });

  it('returns 401 for inactive user', async () => {
    pool.query.mockResolvedValueOnce({ rows: [mockUser({ is_active: false })] });

    const res = await request(app)
      .post('/api/simple-auth/login')
      .send({ email: 'test@example.com', password: 'Test1234' });

    expect(res.status).toBe(401);
    expect(res.body.message).toBe('Invalid email or password');
  });

  it('returns 401 for Google-only user (no password_hash)', async () => {
    pool.query.mockResolvedValueOnce({ rows: [mockUser({ password_hash: null })] });

    const res = await request(app)
      .post('/api/simple-auth/login')
      .send({ email: 'test@example.com', password: 'Test1234' });

    expect(res.status).toBe(401);
    expect(res.body.message).toBe('Invalid email or password');
  });

  it('rejects missing email with 400', async () => {
    const res = await request(app)
      .post('/api/simple-auth/login')
      .send({ password: 'Test1234' });

    expect(res.status).toBe(400);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// CHANGE PASSWORD
// ─────────────────────────────────────────────────────────────────────────────

describe('POST /api/simple-auth/change-password', () => {
  it('rejects unauthenticated request with 401', async () => {
    const res = await request(app)
      .post('/api/simple-auth/change-password')
      .send({ currentPassword: 'Test1234', newPassword: 'NewPass123' });

    expect(res.status).toBe(401);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// FORGOT PASSWORD (anti-enumeration)
// ─────────────────────────────────────────────────────────────────────────────

describe('POST /api/simple-auth/forgot-password', () => {
  it('returns success even for non-existent email (anti-enumeration)', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const res = await request(app)
      .post('/api/simple-auth/forgot-password')
      .send({ email: 'nobody@example.com' });

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/account exists/i);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// PING (sanity)
// ─────────────────────────────────────────────────────────────────────────────

describe('GET /api/simple-auth/ping', () => {
  it('returns ok', async () => {
    const res = await request(app).get('/api/simple-auth/ping');

    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(res.body.service).toBe('simple-auth');
  });
});
