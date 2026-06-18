const { parseLimitValue, DEFAULTS, MIN_LIMIT, MAX_LIMIT } = require('./rideLimitSettings');

describe('rideLimitSettings.parseLimitValue', () => {
  const FB = 99; // distinctive fallback so we can tell when it is used

  test('accepts valid whole numbers as strings', () => {
    expect(parseLimitValue('0', FB)).toBe(0); // kill switch
    expect(parseLimitValue('1', FB)).toBe(1);
    expect(parseLimitValue('4', FB)).toBe(4);
    expect(parseLimitValue(String(MAX_LIMIT), FB)).toBe(MAX_LIMIT);
  });

  test('trims surrounding whitespace', () => {
    expect(parseLimitValue('  7  ', FB)).toBe(7);
  });

  test('rejects floats → fallback', () => {
    expect(parseLimitValue('3.5', FB)).toBe(FB);
    expect(parseLimitValue('2.0', FB)).toBe(FB);
    expect(parseLimitValue('.5', FB)).toBe(FB);
  });

  test('rejects text and emojis → fallback', () => {
    expect(parseLimitValue('abc', FB)).toBe(FB);
    expect(parseLimitValue('5abc', FB)).toBe(FB);
    expect(parseLimitValue('😀', FB)).toBe(FB);
    expect(parseLimitValue('3️⃣', FB)).toBe(FB);
    expect(parseLimitValue('  ', FB)).toBe(FB);
    expect(parseLimitValue('', FB)).toBe(FB);
  });

  test('rejects negatives and out-of-range → fallback', () => {
    expect(parseLimitValue('-1', FB)).toBe(FB);
    expect(parseLimitValue(String(MAX_LIMIT + 1), FB)).toBe(FB);
    expect(parseLimitValue('9999', FB)).toBe(FB);
  });

  test('rejects null/undefined → fallback', () => {
    expect(parseLimitValue(null, FB)).toBe(FB);
    expect(parseLimitValue(undefined, FB)).toBe(FB);
  });

  test('handles numeric (non-string) input defensively', () => {
    expect(parseLimitValue(5, FB)).toBe(5);
    expect(parseLimitValue(3.5, FB)).toBe(FB);
  });

  test('defaults are within the allowed range', () => {
    expect(DEFAULTS.daily).toBeGreaterThanOrEqual(MIN_LIMIT);
    expect(DEFAULTS.daily).toBeLessThanOrEqual(MAX_LIMIT);
    expect(DEFAULTS.weekly).toBeGreaterThanOrEqual(MIN_LIMIT);
    expect(DEFAULTS.weekly).toBeLessThanOrEqual(MAX_LIMIT);
  });
});
