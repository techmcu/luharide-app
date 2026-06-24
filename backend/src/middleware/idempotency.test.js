/**
 * Idempotency middleware — makes a retried write safe (replay, never re-run).
 * Redis is mocked; no real Redis/network.
 */

jest.mock('../config/redis', () => ({
  isRedisEnabled: jest.fn(() => true),
  getRedisClient: jest.fn(),
}));
jest.mock('../config/logger', () => ({
  warn: jest.fn(), info: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { isRedisEnabled, getRedisClient } = require('../config/redis');
const { idempotency } = require('./idempotency');

const flush = () => new Promise((r) => setImmediate(r));

function mkReq(over = {}) {
  return {
    get: (h) => (h === 'Idempotency-Key' ? over.key : undefined),
    user: { id: over.userId || 'u1' },
    method: 'POST',
    baseUrl: '/api/union',
    path: '/schedules/bulk',
  };
}
function mkRes() {
  return {
    statusCode: 200,
    status: jest.fn(function (c) { this.statusCode = c; return this; }),
    json: jest.fn(function () { return this; }),
  };
}
function mkClient(over = {}) {
  return {
    set: jest.fn(over.set || (() => Promise.resolve('OK'))),
    get: jest.fn(over.get || (() => Promise.resolve(null))),
    del: jest.fn(() => Promise.resolve(1)),
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  isRedisEnabled.mockReturnValue(true);
});

test('no Idempotency-Key header → passes through untouched', async () => {
  const req = mkReq({ key: undefined });
  const res = mkRes();
  const next = jest.fn();
  idempotency()(req, res, next);
  await flush();
  expect(next).toHaveBeenCalledTimes(1);
  expect(getRedisClient).not.toHaveBeenCalled();
});

test('Redis disabled → graceful passthrough (never blocks the write)', async () => {
  isRedisEnabled.mockReturnValue(false);
  const req = mkReq({ key: 'k1' });
  const res = mkRes();
  const next = jest.fn();
  idempotency()(req, res, next);
  await flush();
  expect(next).toHaveBeenCalledTimes(1);
});

test('first request claims the key, runs handler, caches the 2xx response', async () => {
  const client = mkClient({ set: () => Promise.resolve('OK') }); // NX claim succeeds
  getRedisClient.mockReturnValue(client);
  const req = mkReq({ key: 'k1' });
  const res = mkRes();
  const next = jest.fn();

  idempotency()(req, res, next);
  await flush();
  expect(next).toHaveBeenCalledTimes(1);

  // handler responds 201 → wrapped json should cache it
  res.statusCode = 201;
  res.json({ success: true, data: { count: 3 } });
  expect(client.set).toHaveBeenCalledWith(
    expect.stringContaining('k1'),
    expect.stringContaining('"status":201'),
    'EX',
    expect.any(Number),
  );
});

test('duplicate with a stored response → replays it, never runs the handler', async () => {
  const stored = JSON.stringify({ status: 201, body: { success: true, data: { count: 3 } } });
  const client = mkClient({
    set: () => Promise.resolve(null),   // NX claim fails → duplicate
    get: () => Promise.resolve(stored),
  });
  getRedisClient.mockReturnValue(client);
  const req = mkReq({ key: 'k1' });
  const res = mkRes();
  const next = jest.fn();

  idempotency()(req, res, next);
  await flush();
  await flush();

  expect(next).not.toHaveBeenCalled();
  expect(res.status).toHaveBeenCalledWith(201);
  expect(res.json).toHaveBeenCalledWith({ success: true, data: { count: 3 } });
});

test('duplicate still in flight (PENDING) → 409, handler not run', async () => {
  const client = mkClient({
    set: () => Promise.resolve(null),
    get: () => Promise.resolve('PENDING'),
  });
  getRedisClient.mockReturnValue(client);
  const req = mkReq({ key: 'k1' });
  const res = mkRes();
  const next = jest.fn();

  idempotency()(req, res, next);
  await flush();
  await flush();

  expect(next).not.toHaveBeenCalled();
  expect(res.status).toHaveBeenCalledWith(409);
});

test('a non-2xx response releases the key so a genuine retry can proceed', async () => {
  const client = mkClient({ set: () => Promise.resolve('OK') });
  getRedisClient.mockReturnValue(client);
  const req = mkReq({ key: 'k1' });
  const res = mkRes();
  const next = jest.fn();

  idempotency()(req, res, next);
  await flush();

  res.statusCode = 400;
  res.json({ success: false });
  expect(client.del).toHaveBeenCalledWith(expect.stringContaining('k1'));
});

test('Redis error during claim → graceful passthrough', async () => {
  const client = mkClient({ set: () => Promise.reject(new Error('redis down')) });
  getRedisClient.mockReturnValue(client);
  const req = mkReq({ key: 'k1' });
  const res = mkRes();
  const next = jest.fn();

  idempotency()(req, res, next);
  await flush();
  expect(next).toHaveBeenCalledTimes(1);
});
