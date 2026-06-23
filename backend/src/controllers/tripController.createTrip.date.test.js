/**
 * departureTimeError — new-ride date rule (future + >=30 min ahead).
 * Pure function, deterministic via injected `now`. Guards against regressions
 * that would wrongly reject valid future rides (the "past past" bug class).
 */
const { departureTimeError } = require('./tripController');

const NOW = Date.UTC(2026, 5, 23, 12, 0, 0); // fixed reference instant

function at(msFromNow) {
  return new Date(NOW + msFromNow);
}
const MIN = 60 * 1000;

describe('departureTimeError', () => {
  it('accepts a clearly-future ride (2 hours ahead) — no error', () => {
    expect(departureTimeError(at(120 * MIN), NOW)).toBeNull();
  });

  it('accepts a UTC ISO ride (client sends toUtc().toIso8601String())', () => {
    // IST 30 Jun 08:00 == 02:30 UTC; well in the future vs NOW → valid
    const d = new Date('2026-06-30T02:30:00.000Z');
    expect(departureTimeError(d, NOW)).toBeNull();
  });

  it('rejects a ride in the past', () => {
    expect(departureTimeError(at(-MIN), NOW)).toBe('Departure time cannot be in the past');
  });

  it('rejects a ride less than 30 minutes ahead', () => {
    expect(departureTimeError(at(20 * MIN), NOW)).toContain('at least 30 minutes');
  });

  it('accepts a ride exactly 30 minutes ahead (boundary)', () => {
    expect(departureTimeError(at(30 * MIN), NOW)).toBeNull();
  });

  it('rejects an invalid date', () => {
    expect(departureTimeError(new Date('not-a-date'), NOW)).toContain('Invalid departure_time');
  });
});
