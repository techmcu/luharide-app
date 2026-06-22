const { estimateFare, validateFare, roundTo } = require('./fareService');

describe('fareService.estimateFare', () => {
  it('returns null for invalid / non-positive / absurd distances', () => {
    for (const d of [null, undefined, 'abc', 0, -5, NaN, 99999]) {
      expect(estimateFare(d)).toBeNull();
    }
  });

  it('produces a fair price and a higher max for a normal route', () => {
    const e = estimateFare(145); // ~Purola↔Dehradun
    expect(e).not.toBeNull();
    expect(e.fair).toBeGreaterThan(300);
    expect(e.fair).toBeLessThan(600);
    expect(e.max).toBeGreaterThan(e.fair); // ceiling above fair
  });

  it('gives higher effective ₹/km for short rides than long rides (natural decay)', () => {
    const short = estimateFare(4);
    const long = estimateFare(145);
    expect(short.perKmEffective).toBeGreaterThan(long.perKmEffective);
  });

  it('never goes below the absolute minimum fare', () => {
    const e = estimateFare(0.5);
    expect(e.fair).toBeGreaterThanOrEqual(10);
  });
});

describe('fareService.validateFare', () => {
  it('rejects non-numeric / negative input as invalid', () => {
    expect(validateFare('x', 145).status).toBe('invalid');
    expect(validateFare(-1, 145).status).toBe('invalid');
  });

  it("returns 'unknown' (allowed) when distance is unavailable", () => {
    expect(validateFare(500, null).status).toBe('unknown');
  });

  it('accepts any price at or below the ceiling, including very low ones', () => {
    const { max } = estimateFare(145);
    expect(validateFare(max, 145).status).toBe('ok');
    expect(validateFare(50, 145).status).toBe('ok');   // very low — driver's choice
    expect(validateFare(1, 145).status).toBe('ok');
  });

  it('blocks prices above the ceiling and reveals only the max (not the fair price)', () => {
    const { max } = estimateFare(145);
    const r = validateFare(max + 1000, 145);
    expect(r.status).toBe('over');
    expect(r.maxAllowed).toBe(max);
    expect(r.message).toContain(String(max));
  });
});

describe('fareService.roundTo', () => {
  it('rounds to the nearest step and tolerates a bad step', () => {
    expect(roundTo(446, 5)).toBe(445);
    expect(roundTo(123, 0)).toBe(123); // step<=0 guarded to 1
  });
});
