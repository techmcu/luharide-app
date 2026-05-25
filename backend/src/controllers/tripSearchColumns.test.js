/**
 * Verify search column constants are defined and the searchLimiter is exported.
 * Prevents regressions like accidentally reverting to SELECT t.* or losing the rate limiter.
 */

describe('trip search column constants', () => {
  let fileContent;

  beforeAll(() => {
    const fs = require('fs');
    const path = require('path');
    fileContent = fs.readFileSync(path.join(__dirname, 'tripController.js'), 'utf8');
  });

  it('defines _TRIP_COLS with explicit columns (no SELECT t.*)', () => {
    expect(fileContent).toContain('const _TRIP_COLS');
    expect(fileContent).toContain('t.id');
    expect(fileContent).toContain('t.available_seats');
    expect(fileContent).toContain('t.departure_time');
  });

  it('defines _DRIVER_COLS with user columns', () => {
    expect(fileContent).toContain('const _DRIVER_COLS');
    expect(fileContent).toContain('driver_name');
    expect(fileContent).toContain('driver_email');
  });

  it('uses _TRIP_COLS in search queries (not SELECT t.*)', () => {
    const start = fileContent.indexOf('const searchTrips');
    const end = fileContent.indexOf('const getTripDetails');
    const searchSection = fileContent.slice(start, end);
    expect(searchSection).toContain('${_TRIP_COLS}');
    expect(searchSection).not.toContain('SELECT t.*');
  });

  it('uses Promise.allSettled for crash safety', () => {
    expect(fileContent).toContain('Promise.allSettled');
    expect(fileContent).toContain('_tripsSettled');
    expect(fileContent).toContain('_unionSettled');
  });

  it('rejects trip creation with past departure time', () => {
    expect(fileContent).toContain('Departure time cannot be in the past');
  });

  it('uses parameterized make_interval in getMyTrips (no SQL interpolation)', () => {
    const myTripsSection = fileContent.slice(fileContent.indexOf('const getMyTrips'));
    expect(myTripsSection).toContain('make_interval');
    expect(myTripsSection).not.toMatch(/INTERVAL '\$\{days\}/);
  });
});

describe('searchLimiter export', () => {
  it('rateLimiter exports searchLimiter', () => {
    const limiter = require('../middleware/rateLimiter');
    expect(limiter.searchLimiter).toBeDefined();
    expect(typeof limiter.searchLimiter).toBe('function');
  });
});
