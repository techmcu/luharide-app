/**
 * JWT authentication + role authorization middleware
 * SOP: SEC-001→005 (security/auth)
 * DB, token service, and cache are mocked — no real database connection.
 */

jest.mock('../config/database', () => ({
  pool: { query: jest.fn() },
}));
jest.mock('../services/tokenService', () => ({
  verifyAccessToken: jest.fn(),
}));
jest.mock('../utils/userCache', () => ({
  get: jest.fn(),
  set: jest.fn(),
  invalidate: jest.fn(),
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { pool } = require('../config/database');
const { verifyAccessToken } = require('../services/tokenService');
const userCache = require('../utils/userCache');
const { authenticate, authorize } = require('./auth');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const USER_ID = 'b0000000-0000-0000-0000-000000000001';
const userRow = {
  id: USER_ID, name: 'Test', email: 'test@x.com', phone: '9876543210',
  role: 'passenger', is_active: true, is_verified: true,
  driver_verification_status: 'none',
};

describe('authenticate', () => {
  beforeEach(() => jest.clearAllMocks());

  it('rejects missing Authorization header', async () => {
    const req = { headers: {} };
    const next = jest.fn();
    authenticate(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401 }));
  });

  it('rejects malformed Authorization header', async () => {
    const req = { headers: { authorization: 'NotBearer xyz' } };
    const next = jest.fn();
    authenticate(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401 }));
  });

  it('authenticates valid token from DB', async () => {
    verifyAccessToken.mockReturnValue({ userId: USER_ID });
    userCache.get.mockReturnValue(null);
    pool.query.mockResolvedValueOnce({ rows: [userRow] });

    const req = { headers: { authorization: 'Bearer valid-jwt' } };
    const next = jest.fn();
    authenticate(req, mockRes(), next);
    await flush();

    expect(req.user).toBeDefined();
    expect(req.user.id).toBe(USER_ID);
    expect(next).toHaveBeenCalledWith();
  });

  it('authenticates valid token from cache', async () => {
    verifyAccessToken.mockReturnValue({ userId: USER_ID });
    userCache.get.mockReturnValue(userRow);

    const req = { headers: { authorization: 'Bearer cached-jwt' } };
    const next = jest.fn();
    authenticate(req, mockRes(), next);
    await flush();

    expect(req.user.id).toBe(USER_ID);
    expect(pool.query).not.toHaveBeenCalled();
  });

  it('rejects deactivated user', async () => {
    verifyAccessToken.mockReturnValue({ userId: USER_ID });
    userCache.get.mockReturnValue(null);
    pool.query.mockResolvedValueOnce({ rows: [{ ...userRow, is_active: false }] });

    const req = { headers: { authorization: 'Bearer deactivated-jwt' } };
    const next = jest.fn();
    authenticate(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
    expect(userCache.invalidate).toHaveBeenCalledWith(USER_ID);
  });

  it('rejects when user not found in DB', async () => {
    verifyAccessToken.mockReturnValue({ userId: USER_ID });
    userCache.get.mockReturnValue(null);
    pool.query.mockResolvedValueOnce({ rows: [] });

    const req = { headers: { authorization: 'Bearer orphan-jwt' } };
    const next = jest.fn();
    authenticate(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401 }));
  });
});

describe('authorize', () => {
  it('allows matching role', async () => {
    const middleware = authorize('passenger', 'driver');
    const req = { user: { role: 'passenger', email: 'test@x.com' } };
    const next = jest.fn();
    middleware(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith();
  });

  it('rejects non-matching role', async () => {
    const middleware = authorize('admin');
    const req = { user: { role: 'passenger', email: 'test@x.com' } };
    const next = jest.fn();
    middleware(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
  });

  it('rejects when no user on request', async () => {
    const middleware = authorize('passenger');
    const req = {};
    const next = jest.fn();
    middleware(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 401 }));
  });

  it('handles case-insensitive role comparison', async () => {
    const middleware = authorize('Passenger');
    const req = { user: { role: 'passenger', email: 'test@x.com' } };
    const next = jest.fn();
    middleware(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith();
  });
});
