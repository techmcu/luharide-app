/**
 * Verify search column constants are defined and the searchLimiter is exported.
 * Prevents regressions like accidentally reverting to SELECT t.* or losing the rate limiter.
 */

describe('trip search column constants', () => {
  let searchContent;
  let mainContent;

  beforeAll(() => {
    const fs = require('fs');
    const path = require('path');
    searchContent = fs.readFileSync(path.join(__dirname, 'trip', 'tripSearchController.js'), 'utf8');
    mainContent = fs.readFileSync(path.join(__dirname, 'tripController.js'), 'utf8');
  });

  it('defines _TRIP_COLS with explicit columns (no SELECT t.*)', () => {
    expect(searchContent).toContain('const _TRIP_COLS');
    expect(searchContent).toContain('t.id');
    expect(searchContent).toContain('t.available_seats');
    expect(searchContent).toContain('t.departure_time');
  });

  it('defines _DRIVER_COLS with user columns', () => {
    expect(searchContent).toContain('const _DRIVER_COLS');
    expect(searchContent).toContain('driver_name');
    expect(searchContent).toContain('driver_email');
  });

  it('uses _TRIP_COLS in search queries (not SELECT t.*)', () => {
    const start = searchContent.indexOf('const searchTrips');
    const searchSection = searchContent.slice(start);
    expect(searchSection).toContain('${_TRIP_COLS}');
    expect(searchSection).not.toContain('SELECT t.*');
  });

  it('uses Promise.allSettled for crash safety', () => {
    expect(searchContent).toContain('Promise.allSettled');
    expect(searchContent).toContain('_tripsSettled');
    expect(searchContent).toContain('_unionSettled');
  });

  it('rejects trip creation with past departure time', () => {
    expect(mainContent).toContain('Departure time cannot be in the past');
  });

  it('uses parameterized make_interval in getMyTrips (no SQL interpolation)', () => {
    const myTripsSection = mainContent.slice(mainContent.indexOf('const getMyTrips'));
    expect(myTripsSection).toContain('make_interval');
    expect(myTripsSection).not.toMatch(/INTERVAL '\$\{days\}/);
  });

  it('barrel re-exports sub-controllers', () => {
    expect(mainContent).toContain("require('./trip/tripSearchController')");
    expect(mainContent).toContain("require('./trip/tripLifecycleController')");
  });
});

describe('searchLimiter export', () => {
  it('rateLimiter exports searchLimiter', () => {
    const limiter = require('../middleware/rateLimiter');
    expect(limiter.searchLimiter).toBeDefined();
    expect(typeof limiter.searchLimiter).toBe('function');
  });
});
