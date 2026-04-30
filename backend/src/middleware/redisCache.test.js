const { redisCache } = require('./redisCache');

jest.mock('../config/redis', () => ({
  isRedisEnabled: jest.fn(),
  getRedisClient: jest.fn(),
}));

const { isRedisEnabled, getRedisClient } = require('../config/redis');

function mockReqRes(method = 'GET', url = '/api/test') {
  const req = { method, originalUrl: url };
  const res = {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    json: jest.fn(),
  };
  return { req, res };
}

describe('redisCache middleware', () => {
  beforeEach(() => jest.clearAllMocks());

  test('skips non-GET requests', () => {
    isRedisEnabled.mockReturnValue(true);
    const mw = redisCache(60);
    const { req, res } = mockReqRes('POST');
    const next = jest.fn();
    mw(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  test('skips when Redis is disabled', () => {
    isRedisEnabled.mockReturnValue(false);
    const mw = redisCache(60);
    const { req, res } = mockReqRes();
    const next = jest.fn();
    mw(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  test('skips when Redis client is null', () => {
    isRedisEnabled.mockReturnValue(true);
    getRedisClient.mockReturnValue(null);
    const mw = redisCache(60);
    const { req, res } = mockReqRes();
    const next = jest.fn();
    mw(req, res, next);
    expect(next).toHaveBeenCalled();
  });

  test('returns cached response on hit', async () => {
    const cached = JSON.stringify({ ok: true, data: [1, 2, 3] });
    const client = { get: jest.fn().mockResolvedValue(cached) };
    isRedisEnabled.mockReturnValue(true);
    getRedisClient.mockReturnValue(client);

    const mw = redisCache(60);
    const { req, res } = mockReqRes('GET', '/api/reviews/user/1/summary');
    const next = jest.fn();

    await new Promise((resolve) => {
      res.json = jest.fn(() => resolve());
      mw(req, res, next);
    });

    expect(next).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith({ ok: true, data: [1, 2, 3] });
  });

  test('calls next and caches on miss', async () => {
    const client = {
      get: jest.fn().mockResolvedValue(null),
      setex: jest.fn().mockResolvedValue('OK'),
    };
    isRedisEnabled.mockReturnValue(true);
    getRedisClient.mockReturnValue(client);

    const mw = redisCache(30, 'test');
    const { req, res } = mockReqRes('GET', '/api/trips/search?from=A');
    const next = jest.fn();

    await new Promise((resolve) => {
      const origNext = () => {
        resolve();
      };
      mw(req, res, origNext);
    });

    // Simulate controller sending response
    const body = { trips: [] };
    res.json(body);

    expect(client.setex).toHaveBeenCalledWith(
      'test:/api/trips/search?from=A',
      30,
      JSON.stringify(body)
    );
  });

  test('does not cache error responses', async () => {
    const client = {
      get: jest.fn().mockResolvedValue(null),
      setex: jest.fn().mockResolvedValue('OK'),
    };
    isRedisEnabled.mockReturnValue(true);
    getRedisClient.mockReturnValue(client);

    const mw = redisCache(30);
    const { req, res } = mockReqRes();
    const next = jest.fn();

    await new Promise((resolve) => {
      mw(req, res, () => resolve());
    });

    res.statusCode = 500;
    res.json({ error: 'fail' });

    expect(client.setex).not.toHaveBeenCalled();
  });

  test('falls through on Redis get error', async () => {
    const client = { get: jest.fn().mockRejectedValue(new Error('ECONNREFUSED')) };
    isRedisEnabled.mockReturnValue(true);
    getRedisClient.mockReturnValue(client);

    const mw = redisCache(60);
    const { req, res } = mockReqRes();
    const next = jest.fn();

    await new Promise((resolve) => {
      mw(req, res, () => { next(); resolve(); });
    });

    expect(next).toHaveBeenCalled();
  });
});
