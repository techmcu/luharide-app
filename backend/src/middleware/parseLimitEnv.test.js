const { parseLimitEnv } = require('./parseLimitEnv');

const envKey = '__PARSE_LIMIT_ENV_TEST__';

describe('parseLimitEnv', () => {
  const prev = process.env[envKey];

  afterEach(() => {
    if (prev === undefined) delete process.env[envKey];
    else process.env[envKey] = prev;
  });

  it('returns default when env missing or empty', () => {
    delete process.env[envKey];
    expect(parseLimitEnv(envKey, 7, 1, 10)).toBe(7);
    process.env[envKey] = '';
    expect(parseLimitEnv(envKey, 7, 1, 10)).toBe(7);
  });

  it('clamps to min/max', () => {
    process.env[envKey] = '0';
    expect(parseLimitEnv(envKey, 5, 2, 8)).toBe(2);
    process.env[envKey] = '100';
    expect(parseLimitEnv(envKey, 5, 2, 8)).toBe(8);
    process.env[envKey] = '4';
    expect(parseLimitEnv(envKey, 5, 2, 8)).toBe(4);
  });

  it('returns default on non-numeric', () => {
    process.env[envKey] = 'abc';
    expect(parseLimitEnv(envKey, 3, 1, 10)).toBe(3);
  });
});
