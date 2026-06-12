/**
 * Cancel trip edge cases — SOP BL-017→023
 * DB and socket are mocked — no real database connection.
 */

jest.mock('../config/database', () => ({
  pool: { connect: jest.fn(), query: jest.fn() },
  queryRead: jest.fn(),
}));
jest.mock('../socket/realtimeEmitter', () => ({
  emitTripUpdated: jest.fn(),
  emitNotificationToUser: jest.fn(),
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { pool } = require('../config/database');
const { cancelTrip } = require('./tripController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const TRIP_ID   = 'a0000000-0000-0000-0000-000000000001';
const DRIVER_ID = 'b0000000-0000-0000-0000-000000000001';
const PASS_ID   = 'c0000000-0000-0000-0000-000000000001';

const futureISO = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
const pastISO   = new Date(Date.now() - 60000).toISOString();

describe('cancelTrip', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
    pool.query.mockResolvedValue({ rows: [{ cancel_blocked_until: null }] });
  });

  // ── SOP BL-017: Already cancelled trip ────────────────────────────────────
  it('rejects cancel of already cancelled trip', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })    // BEGIN
      .mockResolvedValueOnce({ rows: [{
        id: TRIP_ID, status: 'cancelled', driver_id: DRIVER_ID, departure_time: futureISO,
      }] });

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    cancelTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-018: Completed trip can't be cancelled ─────────────────────────
  it('rejects cancel of completed trip', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{
        id: TRIP_ID, status: 'completed', driver_id: DRIVER_ID, departure_time: futureISO,
      }] });

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    cancelTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-019: In-progress trip can't be cancelled ───────────────────────
  it('rejects cancel of in_progress trip', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{
        id: TRIP_ID, status: 'in_progress', driver_id: DRIVER_ID, departure_time: pastISO,
      }] });

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    cancelTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-020: After departure → blocked ────────────────────────────────
  it('rejects cancel after departure time passed', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{
        id: TRIP_ID, status: 'scheduled', driver_id: DRIVER_ID, departure_time: pastISO,
      }] });

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    cancelTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-021: Wrong driver → 404 ───────────────────────────────────────
  it('rejects cancel by non-owner driver', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] }); // no trip for this driver

    const req = { params: { id: TRIP_ID }, user: { id: 'x0000000-0000-0000-0000-000000000099' } };
    const next = jest.fn();
    cancelTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 404 }));
  });

  // ── Cancel-blocked driver ─────────────────────────────────────────────────
  it('rejects cancel when driver is cancel-blocked', async () => {
    const futureBlock = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    pool.query.mockResolvedValueOnce({ rows: [{ cancel_blocked_until: futureBlock }] });

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    cancelTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── Invalid UUID ──────────────────────────────────────────────────────────
  it('rejects invalid trip UUID', async () => {
    const req = { params: { id: 'not-uuid' }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    cancelTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-022: Cancel cascades — all active bookings cancelled ───────────
  it('cancels all active bookings when trip cancelled', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })       // BEGIN
      .mockResolvedValueOnce({ rows: [{          // SELECT trip FOR UPDATE
        id: TRIP_ID, status: 'scheduled', driver_id: DRIVER_ID,
        departure_time: futureISO, created_at: new Date().toISOString(),
      }] })
      .mockResolvedValueOnce({ rows: [           // SELECT active bookings
        { id: 'bk1', passenger_id: PASS_ID, seat_numbers: [2, 3], status: 'confirmed' },
        { id: 'bk2', passenger_id: 'd000-0002', seat_numbers: [4], status: 'pending' },
      ] })
      .mockResolvedValueOnce({ rows: [] })       // UPDATE bookings SET cancelled
      .mockResolvedValueOnce({ rows: [] })       // UPDATE trips SET cancelled + seats
      .mockResolvedValueOnce({ rows: [] })       // INSERT notifications
      .mockResolvedValueOnce({ rows: [] });      // COMMIT

    pool.query
      .mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] })  // block check
      .mockResolvedValueOnce({ rows: [] })       // DELETE pending_rate_notifications
      .mockResolvedValueOnce({ rows: [{ recent: 1, long_term: 1 }] })    // cancel count
      .mockResolvedValue({ rows: [] });          // remaining calls

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    const res = mockRes();
    cancelTrip(req, res, jest.fn());
    await flush();

    const cancelUpdate = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes("status = 'cancelled'") && sql.includes('bookings')
    );
    expect(cancelUpdate).toBeTruthy();
  });

  // ── SOP BL-023: Passengers notified on trip cancel ────────────────────────
  it('creates notifications for passengers when trip cancelled', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })       // BEGIN
      .mockResolvedValueOnce({ rows: [{          // SELECT trip FOR UPDATE
        id: TRIP_ID, status: 'scheduled', driver_id: DRIVER_ID,
        departure_time: futureISO, created_at: new Date().toISOString(),
      }] })
      .mockResolvedValueOnce({ rows: [           // SELECT active bookings
        { id: 'bk1', passenger_id: PASS_ID, seat_numbers: [2], status: 'confirmed' },
      ] })
      .mockResolvedValueOnce({ rows: [] })       // UPDATE bookings SET cancelled
      .mockResolvedValueOnce({ rows: [] })       // UPDATE trips SET cancelled + seats
      .mockResolvedValueOnce({                   // INSERT notifications RETURNING
        rows: [{ id: 'n1', user_id: PASS_ID, type: 'trip_cancelled' }],
      })
      .mockResolvedValueOnce({ rows: [] });      // COMMIT

    pool.query
      .mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] })
      .mockResolvedValueOnce({ rows: [] })       // rate cleanup
      .mockResolvedValueOnce({ rows: [{ recent: 1, long_term: 1 }] })
      .mockResolvedValue({ rows: [] });

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    cancelTrip(req, mockRes(), jest.fn());
    await flush();

    const notifInsert = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('INSERT INTO notifications') && sql.includes('trip_cancelled')
    );
    expect(notifInsert).toBeTruthy();
  });
});
