const { recordMiddleware, getMetrics } = require('./metricsCollector');

jest.mock('../config/redis', () => ({
  isRedisEnabled: jest.fn(() => false),
  getRedisClient: jest.fn(() => null),
}));

function mockReqRes(statusCode = 200) {
  const req = {};
  const listeners = {};
  const res = {
    statusCode,
    on(event, fn) { listeners[event] = fn; },
    _fire(event) { if (listeners[event]) listeners[event](); },
  };
  return { req, res, fire: () => res._fire('finish') };
}

describe('metricsCollector', () => {
  test('recordMiddleware tracks requests', () => {
    const mw = recordMiddleware();
    const next = jest.fn();
    const { req, res, fire } = mockReqRes(200);

    mw(req, res, next);
    expect(next).toHaveBeenCalled();
    fire();
  });

  test('getMetrics returns expected shape', async () => {
    const data = await getMetrics('test-svc', null);
    expect(data.ok).toBe(true);
    expect(data.service).toBe('test-svc');
    expect(data.worker_id).toBeDefined();
    expect(data.aggregated).toBe(false);
    expect(typeof data.requests_total).toBe('number');
    expect(typeof data.status_2xx).toBe('number');
    expect(typeof data.latency_ms.p50).toBe('number');
    expect(data.memory_mb).toBeDefined();
    expect(data.cpu).toBeDefined();
    expect(data.db_pool).toBeUndefined();
  });

  test('getMetrics includes db_pool when pool provided', async () => {
    const fakePool = { totalCount: 5, idleCount: 3, waitingCount: 0 };
    const data = await getMetrics('test', fakePool);
    expect(data.db_pool).toEqual({ total: 5, idle: 3, waiting: 0 });
  });
});
