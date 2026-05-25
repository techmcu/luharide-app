const config = require('./retentionConfig');

describe('retentionConfig', () => {
  it('exports an object with all expected keys', () => {
    const keys = Object.keys(config);
    expect(keys.length).toBeGreaterThan(10);
  });

  it('all values are finite numbers', () => {
    for (const [key, val] of Object.entries(config)) {
      expect(typeof val).toBe('number');
      expect(Number.isFinite(val)).toBe(true);
    }
  });

  it('pendingBookingExpiryHours defaults to 24', () => {
    expect(config.pendingBookingExpiryHours).toBe(24);
  });

  it('trip retention days are positive', () => {
    expect(config.tripRetentionDaysIndependent).toBeGreaterThan(0);
    expect(config.tripRetentionDaysUnion).toBeGreaterThan(0);
  });

  it('notification retention hours are positive', () => {
    expect(config.notificationReadRetentionHours).toBeGreaterThan(0);
    expect(config.notificationUnreadRetentionHours).toBeGreaterThan(0);
  });

  it('tripAutoCompleteAfterDepartureHours is non-negative', () => {
    expect(config.tripAutoCompleteAfterDepartureHours).toBeGreaterThanOrEqual(0);
  });
});
