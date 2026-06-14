/**
 * tokenService unit tests — auth backbone: JWT generation, verification, revocation.
 * All DB calls and config are mocked.
 *
 * Note: tokenService has a module-level _schemaReady singleton. We re-require
 * the module in tests that need fresh schema detection.
 */

jest.mock('../config/database', () => ({
  pool: { query: jest.fn() },
}));
jest.mock('../config/env', () => ({
  config: { jwt: { secret: 'test-jwt-secret-key-for-unit-tests' } },
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');

const JWT_SECRET = 'test-jwt-secret-key-for-unit-tests';
const USER_ID = 'a0000000-0000-0000-0000-000000000001';
const ROLE = 'passenger';

/**
 * Helper: re-require tokenService with a fresh module cache so _schemaReady resets.
 */
function freshTokenService() {
  jest.resetModules();
  // Re-mock after resetModules
  jest.mock('../config/database', () => ({
    pool: { query: jest.fn() },
  }));
  jest.mock('../config/env', () => ({
    config: { jwt: { secret: 'test-jwt-secret-key-for-unit-tests' } },
  }));
  jest.mock('../config/logger', () => ({
    info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
  }));
  const freshPool = require('../config/database').pool;
  const svc = require('./tokenService');
  return { svc, pool: freshPool };
}

// For pure-function tests (no DB), use a single require
const {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
} = require('./tokenService');

beforeEach(() => {
  jest.clearAllMocks();
});

// ── generateAccessToken ──────────────────────────────────────────────────────

describe('generateAccessToken', () => {
  it('returns a valid JWT with correct payload', () => {
    const token = generateAccessToken(USER_ID, ROLE);
    const decoded = jwt.verify(token, JWT_SECRET);

    expect(decoded.userId).toBe(USER_ID);
    expect(decoded.role).toBe(ROLE);
    expect(decoded.type).toBe('access');
    expect(decoded.exp).toBeDefined();
  });

  it('uses HS256 algorithm', () => {
    const token = generateAccessToken(USER_ID, ROLE);
    const header = JSON.parse(Buffer.from(token.split('.')[0], 'base64url').toString());
    expect(header.alg).toBe('HS256');
  });
});

// ── generateRefreshToken ─────────────────────────────────────────────────────

describe('generateRefreshToken', () => {
  it('returns a valid JWT with type refresh and jti', () => {
    const token = generateRefreshToken(USER_ID, ROLE);
    const decoded = jwt.verify(token, JWT_SECRET);

    expect(decoded.userId).toBe(USER_ID);
    expect(decoded.role).toBe(ROLE);
    expect(decoded.type).toBe('refresh');
    expect(decoded.jti).toBeDefined();
    expect(decoded.jti).toHaveLength(32); // 16 bytes hex
  });
});

// ── verifyAccessToken ────────────────────────────────────────────────────────

describe('verifyAccessToken', () => {
  it('succeeds with a valid access token', () => {
    const token = generateAccessToken(USER_ID, ROLE);
    const decoded = verifyAccessToken(token);

    expect(decoded.userId).toBe(USER_ID);
    expect(decoded.role).toBe(ROLE);
    expect(decoded.type).toBe('access');
  });

  it('throws on expired token', () => {
    const token = jwt.sign(
      { userId: USER_ID, role: ROLE, type: 'access' },
      JWT_SECRET,
      { expiresIn: '0s' }
    );

    expect(() => verifyAccessToken(token)).toThrow('Token expired');
  });

  it('throws on invalid/tampered token', () => {
    expect(() => verifyAccessToken('not.a.valid.token')).toThrow('Invalid token');
  });

  it('rejects refresh tokens (wrong type)', () => {
    const refreshToken = generateRefreshToken(USER_ID, ROLE);
    expect(() => verifyAccessToken(refreshToken)).toThrow('Invalid token type');
  });
});

// ── verifyRefreshToken ───────────────────────────────────────────────────────

describe('verifyRefreshToken', () => {
  it('succeeds when DB finds the token', async () => {
    const { svc, pool: p } = freshTokenService();
    const token = svc.generateRefreshToken(USER_ID, ROLE);

    // ensureSchema: schema column check + ALTER TABLE + actual token lookup
    p.query
      .mockResolvedValueOnce({ rows: [{ column_name: 'token_hash' }] }) // schema check
      .mockResolvedValueOnce({}) // ALTER TABLE
      .mockResolvedValueOnce({ rows: [{ id: 42 }] }); // token lookup

    const decoded = await svc.verifyRefreshToken(token);
    expect(decoded.userId).toBe(USER_ID);
    expect(decoded.type).toBe('refresh');
    expect(decoded.tokenId).toBe(42);
  });

  it('throws when token not found in DB', async () => {
    const { svc, pool: p } = freshTokenService();
    const token = svc.generateRefreshToken(USER_ID, ROLE);

    p.query
      .mockResolvedValueOnce({ rows: [{ column_name: 'token_hash' }] })
      .mockResolvedValueOnce({}) // ALTER TABLE
      .mockResolvedValueOnce({ rows: [] }); // not found

    await expect(svc.verifyRefreshToken(token)).rejects.toThrow(
      'Refresh token is invalid or expired'
    );
  });

  it('rejects access tokens (wrong type)', async () => {
    const { svc, pool: p } = freshTokenService();
    const token = svc.generateAccessToken(USER_ID, ROLE);

    p.query
      .mockResolvedValueOnce({ rows: [{ column_name: 'token_hash' }] })
      .mockResolvedValueOnce({}); // ALTER TABLE

    await expect(svc.verifyRefreshToken(token)).rejects.toThrow('Invalid token type');
  });
});

// ── storeRefreshToken ────────────────────────────────────────────────────────

describe('storeRefreshToken', () => {
  it('inserts token with hashed mode when token_hash column exists', async () => {
    const { svc, pool: p } = freshTokenService();
    const token = svc.generateRefreshToken(USER_ID, ROLE);

    p.query
      .mockResolvedValueOnce({ rows: [{ column_name: 'token_hash' }] }) // schema
      .mockResolvedValueOnce({}) // ALTER TABLE
      .mockResolvedValueOnce({ rows: [{ id: 99 }] }); // INSERT

    const id = await svc.storeRefreshToken(USER_ID, token, { device: 'test' }, '127.0.0.1');
    expect(id).toBe(99);

    // The INSERT call is the third query
    const insertCall = p.query.mock.calls[2];
    expect(insertCall[0]).toContain('token_hash');
    expect(insertCall[1][0]).toBe(USER_ID);
  });

  it('retries on duplicate key error (23505)', async () => {
    const { svc, pool: p } = freshTokenService();
    const token = svc.generateRefreshToken(USER_ID, ROLE);
    const dupeError = new Error('duplicate key');
    dupeError.code = '23505';

    p.query
      .mockResolvedValueOnce({ rows: [{ column_name: 'token_hash' }] }) // schema
      .mockResolvedValueOnce({}) // ALTER TABLE
      .mockRejectedValueOnce(dupeError) // first INSERT fails
      .mockResolvedValueOnce({ rowCount: 1 }) // UPDATE revoke stale
      .mockResolvedValueOnce({ rows: [{ id: 101 }] }); // retry INSERT

    const id = await svc.storeRefreshToken(USER_ID, token);
    expect(id).toBe(101);
  });
});

// ── revokeRefreshToken ───────────────────────────────────────────────────────

describe('revokeRefreshToken', () => {
  it('returns true when token is revoked', async () => {
    const { svc, pool: p } = freshTokenService();

    p.query
      .mockResolvedValueOnce({ rows: [{ column_name: 'token_hash' }] }) // schema
      .mockResolvedValueOnce({}) // ALTER TABLE
      .mockResolvedValueOnce({ rows: [{ id: 1 }] }); // UPDATE returning

    const result = await svc.revokeRefreshToken('some-token');
    expect(result).toBe(true);
  });

  it('returns false when token not found', async () => {
    const { svc, pool: p } = freshTokenService();

    p.query
      .mockResolvedValueOnce({ rows: [{ column_name: 'token_hash' }] }) // schema
      .mockResolvedValueOnce({}) // ALTER TABLE
      .mockResolvedValueOnce({ rows: [] }); // nothing to revoke

    const result = await svc.revokeRefreshToken('nonexistent-token');
    expect(result).toBe(false);
  });
});

// ── revokeAllUserTokens ──────────────────────────────────────────────────────

describe('revokeAllUserTokens', () => {
  it('returns count of revoked tokens', async () => {
    const { svc, pool: p } = freshTokenService();

    p.query.mockResolvedValueOnce({ rows: [{ id: 1 }, { id: 2 }], rowCount: 2 });

    const count = await svc.revokeAllUserTokens(USER_ID);
    expect(count).toBe(2);
    expect(p.query.mock.calls[0][1]).toEqual([USER_ID]);
  });
});

// ── cleanupExpiredTokens ─────────────────────────────────────────────────────

describe('cleanupExpiredTokens', () => {
  it('runs cleanup query and returns count', async () => {
    const { svc, pool: p } = freshTokenService();

    p.query.mockResolvedValueOnce({ rowCount: 5 });

    const count = await svc.cleanupExpiredTokens();
    expect(count).toBe(5);
    expect(p.query).toHaveBeenCalledWith(expect.stringContaining('DELETE FROM refresh_tokens'));
  });

  it('handles DB errors without throwing', async () => {
    const { svc, pool: p } = freshTokenService();

    p.query.mockRejectedValueOnce(new Error('DB down'));

    // Should not throw — error is logged internally
    await expect(svc.cleanupExpiredTokens()).resolves.toBeUndefined();
  });
});

// ── generateTokenPair ────────────────────────────────────────────────────────

describe('generateTokenPair', () => {
  it('returns both access and refresh tokens and stores refresh', async () => {
    const { svc, pool: p } = freshTokenService();

    // ensureSchema + INSERT
    p.query
      .mockResolvedValueOnce({ rows: [{ column_name: 'token_hash' }] }) // schema
      .mockResolvedValueOnce({}) // ALTER TABLE
      .mockResolvedValueOnce({ rows: [{ id: 7 }] }); // INSERT

    const pair = await svc.generateTokenPair(USER_ID, ROLE);

    expect(pair.accessToken).toBeDefined();
    expect(pair.refreshToken).toBeDefined();

    // Access token is valid
    const accessDecoded = jwt.verify(pair.accessToken, JWT_SECRET);
    expect(accessDecoded.type).toBe('access');
    expect(accessDecoded.userId).toBe(USER_ID);

    // Refresh token is valid
    const refreshDecoded = jwt.verify(pair.refreshToken, JWT_SECRET);
    expect(refreshDecoded.type).toBe('refresh');
  });
});
