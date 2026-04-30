const { ServiceCircuitBreaker, getBreaker } = require('./circuitBreaker');

jest.mock('../src/config/logger', () => ({
  warn: jest.fn(),
  info: jest.fn(),
}));

describe('ServiceCircuitBreaker', () => {
  test('starts CLOSED', () => {
    const cb = new ServiceCircuitBreaker('test');
    expect(cb.state).toBe('CLOSED');
    expect(cb.isAvailable()).toBe(true);
  });

  test('opens after threshold failures', () => {
    const cb = new ServiceCircuitBreaker('test', { failureThreshold: 3 });
    cb.recordFailure();
    cb.recordFailure();
    expect(cb.state).toBe('CLOSED');
    cb.recordFailure();
    expect(cb.state).toBe('OPEN');
    expect(cb.isAvailable()).toBe(false);
  });

  test('transitions to HALF_OPEN after reset timeout', () => {
    const cb = new ServiceCircuitBreaker('test', {
      failureThreshold: 2,
      resetTimeoutMs: 100,
    });
    cb.recordFailure();
    cb.recordFailure();
    expect(cb.state).toBe('OPEN');

    cb.openedAt = Date.now() - 200;
    expect(cb.isAvailable()).toBe(true);
    expect(cb.state).toBe('HALF_OPEN');
  });

  test('closes on success in HALF_OPEN state', () => {
    const cb = new ServiceCircuitBreaker('test', { failureThreshold: 1 });
    cb.recordFailure();
    expect(cb.state).toBe('OPEN');

    cb.openedAt = Date.now() - 999999;
    cb.isAvailable();
    expect(cb.state).toBe('HALF_OPEN');

    cb.recordSuccess();
    expect(cb.state).toBe('CLOSED');
    expect(cb.failures).toHaveLength(0);
  });

  test('recordSuccess is no-op in CLOSED state', () => {
    const cb = new ServiceCircuitBreaker('test');
    cb.recordSuccess();
    expect(cb.state).toBe('CLOSED');
  });

  test('toJSON returns state summary', () => {
    const cb = new ServiceCircuitBreaker('svc');
    cb.recordFailure();
    const json = cb.toJSON();
    expect(json).toEqual({
      name: 'svc',
      state: 'CLOSED',
      recentFailures: 1,
    });
  });

  test('old failures expire outside monitor window', () => {
    const cb = new ServiceCircuitBreaker('test', {
      failureThreshold: 3,
      monitorWindowMs: 100,
    });
    cb.failures = [Date.now() - 200, Date.now() - 150];
    cb.recordFailure();
    expect(cb.failures).toHaveLength(1);
    expect(cb.state).toBe('CLOSED');
  });
});

describe('getBreaker', () => {
  test('returns same instance for same name', () => {
    const a = getBreaker('auth');
    const b = getBreaker('auth');
    expect(a).toBe(b);
  });

  test('returns different instances for different names', () => {
    const a = getBreaker('core');
    const b = getBreaker('union');
    expect(a).not.toBe(b);
  });
});
