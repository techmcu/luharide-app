/**
 * Trip search validation — SOP P-025→030
 * DB is mocked — no real database connection.
 */

jest.mock('../config/database', () => ({
  pool: { query: jest.fn() },
  queryRead: jest.fn(),
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { queryRead } = require('../config/database');
const { searchTrips } = require('./tripController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

describe('searchTrips — validation', () => {
  beforeEach(() => jest.clearAllMocks());

  it('rejects when from, to, and date are all missing', async () => {
    const req = { query: {}, body: {} };
    const next = jest.fn();
    searchTrips(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects when from is missing', async () => {
    const req = { query: { to: 'Purola', date: '2026-06-15' }, body: {} };
    const next = jest.fn();
    searchTrips(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects when date is missing', async () => {
    const req = { query: { from: 'Dehradun', to: 'Purola' }, body: {} };
    const next = jest.fn();
    searchTrips(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects invalid date format', async () => {
    const req = { query: { from: 'Dehradun', to: 'Purola', date: '15-06-2026' }, body: {} };
    const next = jest.fn();
    searchTrips(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('accepts route_id with date (no from/to needed)', async () => {
    queryRead
      .mockResolvedValueOnce({ rows: [] })   // trips
      .mockResolvedValueOnce({ rows: [] });  // union schedules

    const req = {
      query: { route_id: 'r0000000-0000-0000-0000-000000000001', date: '2026-06-15' },
      body: {},
    };
    const res = mockRes();
    searchTrips(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
  });

  it('returns results for valid from/to/date', async () => {
    queryRead
      .mockResolvedValueOnce({ rows: [
        { id: 't1', from_location: 'Dehradun', to_location: 'Purola', departure_time: '2026-06-15T08:00:00Z', available_seats: 3, fare_per_seat: 500, driver_name: 'Test' },
      ] })
      .mockResolvedValueOnce({ rows: [] }); // union

    const req = {
      query: { from: 'Dehradun', to: 'Purola', date: '2026-06-15' },
      body: {},
    };
    const res = mockRes();
    searchTrips(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
  });

  it('accepts from_location/to_location aliases', async () => {
    queryRead
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    const req = {
      query: { from_location: 'Dehradun', to_location: 'Purola', date: '2026-06-15' },
      body: {},
    };
    const res = mockRes();
    searchTrips(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
  });
});
