/**
 * Cancel booking edge cases — SOP Part F (BL-011→016) + Part A (P-038→041)
 * DB and socket are mocked — no real database connection is ever made.
 */

jest.mock('../config/database', () => ({
  pool: { connect: jest.fn(), query: jest.fn() },
}));
jest.mock('../socket/realtimeEmitter', () => ({
  emitTripUpdated: jest.fn(),
  emitNotificationToUser: jest.fn(),
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { pool } = require('../config/database');
const { cancelBooking } = require('./bookingController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const TRIP_ID   = 'a0000000-0000-0000-0000-000000000001';
const DRIVER_ID = 'b0000000-0000-0000-0000-000000000001';
const PASS_ID   = 'c0000000-0000-0000-0000-000000000001';
const BOOK_ID   = 'd0000000-0000-0000-0000-000000000001';

const futureISO = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
const pastISO   = new Date(Date.now() - 60000).toISOString();

function makeBooking(overrides = {}) {
  return {
    id: BOOK_ID,
    trip_id: TRIP_ID,
    passenger_id: PASS_ID,
    driver_id: DRIVER_ID,
    status: 'confirmed',
    seat_numbers: [2, 3],
    booking_created_at: new Date().toISOString(),
    departure_time: futureISO,
    trip_status: 'scheduled',
    ...overrides,
  };
}

describe('cancelBooking', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
    // Default: no cancel block
    pool.query.mockResolvedValue({ rows: [{ cancel_blocked_until: null }] });
  });

  // ── SOP P-038: Cancel pending booking ─────────────────────────────────────
  it('cancels pending booking and restores seats', async () => {
    const booking = makeBooking({ status: 'pending' });

    client.query
      .mockResolvedValueOnce({ rows: [] })          // BEGIN
      .mockResolvedValueOnce({ rows: [booking] })   // SELECT booking FOR UPDATE
      .mockResolvedValueOnce({ rows: [] })           // UPDATE status=cancelled
      .mockResolvedValueOnce({ rows: [] })           // UPDATE available_seats +
      .mockResolvedValueOnce({ rows: [] });          // COMMIT

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: PASS_ID } };
    cancelBooking(req, mockRes(), jest.fn());
    await flush();

    const restore = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('available_seats = available_seats +')
    );
    expect(restore).toBeTruthy();
    expect(restore[1]).toEqual([2, TRIP_ID]);
  });

  // ── SOP P-039: Cancel confirmed booking ───────────────────────────────────
  it('cancels confirmed booking and restores seats', async () => {
    const booking = makeBooking({ status: 'confirmed' });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: PASS_ID } };
    cancelBooking(req, mockRes(), jest.fn());
    await flush();

    const restore = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('available_seats = available_seats +')
    );
    expect(restore).toBeTruthy();
  });

  // ── Already cancelled ─────────────────────────────────────────────────────
  it('rejects cancel for already cancelled booking', async () => {
    const booking = makeBooking({ status: 'cancelled' });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] });

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: PASS_ID } };
    const next = jest.fn();
    cancelBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  // ── Wrong user ────────────────────────────────────────────────────────────
  it('rejects cancel by different passenger', async () => {
    const booking = makeBooking();

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] });

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: 'x0000000-0000-0000-0000-000000000099' } };
    const next = jest.fn();
    cancelBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 403 })
    );
  });

  // ── SOP BL-011 related: Cancel after departure ────────────────────────────
  it('rejects cancel when departure time has passed', async () => {
    const booking = makeBooking({ departure_time: pastISO });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] });

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: PASS_ID } };
    const next = jest.fn();
    cancelBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  // ── Cancel in_progress trip ───────────────────────────────────────────────
  it('rejects cancel when trip is in_progress', async () => {
    const booking = makeBooking({ trip_status: 'in_progress' });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] });

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: PASS_ID } };
    const next = jest.fn();
    cancelBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  // ── Cancel completed trip ─────────────────────────────────────────────────
  it('rejects cancel when trip is completed', async () => {
    const booking = makeBooking({ trip_status: 'completed' });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] });

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: PASS_ID } };
    const next = jest.fn();
    cancelBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  // ── SOP P-041: Cancel with reason ─────────────────────────────────────────
  it('passes cancellation reason to query', async () => {
    const booking = makeBooking({ status: 'pending' });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    const req = { params: { id: BOOK_ID }, body: { reason: 'plans changed' }, user: { id: PASS_ID } };
    cancelBooking(req, mockRes(), jest.fn());
    await flush();

    const cancelUpdate = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes("status = 'cancelled'") && sql.includes('cancellation_reason')
    );
    expect(cancelUpdate).toBeTruthy();
    expect(cancelUpdate[1]).toContain('plans changed');
  });

  // ── SOP BL-008: Cancel-blocked user ───────────────────────────────────────
  it('rejects cancel when user is cancel-blocked', async () => {
    const futureBlock = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    pool.query.mockResolvedValueOnce({
      rows: [{ cancel_blocked_until: futureBlock }],
    });

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: PASS_ID } };
    const next = jest.fn();
    cancelBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  // ── Booking not found ─────────────────────────────────────────────────────
  it('returns 404 for non-existent booking', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })    // BEGIN
      .mockResolvedValueOnce({ rows: [] });   // SELECT — no rows

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: PASS_ID } };
    const next = jest.fn();
    cancelBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 404 })
    );
  });

  // ── Invalid booking ID ────────────────────────────────────────────────────
  it('rejects invalid UUID format', async () => {
    const req = { params: { id: 'not-a-uuid' }, body: {}, user: { id: PASS_ID } };
    const next = jest.fn();
    cancelBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  // ── SOP BL-016: Driver gets notification on confirmed cancel ──────────────
  it('sends driver notification when confirmed booking cancelled', async () => {
    const booking = makeBooking({ status: 'confirmed' });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    // Post-commit pool.query calls: notification INSERT, rate cleanup, cancel tracking, auto-rating, rate notif
    pool.query
      .mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] })  // block check
      .mockResolvedValueOnce({ rows: [{ id: 'n1', user_id: DRIVER_ID }] })  // notification INSERT
      .mockResolvedValueOnce({ rows: [] })   // DELETE pending_rate_notifications
      .mockResolvedValueOnce({ rows: [{ recent: 1, long_term: 1 }] })  // cancel count
      .mockResolvedValueOnce({ rows: [] })   // auto 1-star INSERT
      .mockResolvedValueOnce({ rows: [{ id: 'n2', user_id: DRIVER_ID }] });  // rate notification

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: PASS_ID } };
    cancelBooking(req, mockRes(), jest.fn());
    await flush();

    const notifInsert = pool.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('INSERT INTO notifications') && sql.includes('booking_cancelled')
    );
    expect(notifInsert).toBeTruthy();
  });

  // ── Rate notification cleanup after cancel ────────────────────────────────
  it('cleans up pending rate notifications after cancel', async () => {
    const booking = makeBooking({ status: 'confirmed' });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    pool.query
      .mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] })
      .mockResolvedValueOnce({ rows: [] })   // notification
      .mockResolvedValueOnce({ rows: [] })   // DELETE pending_rate_notifications
      .mockResolvedValueOnce({ rows: [{ recent: 1, long_term: 1 }] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    const req = { params: { id: BOOK_ID }, body: {}, user: { id: PASS_ID } };
    cancelBooking(req, mockRes(), jest.fn());
    await flush();

    const rateCleanup = pool.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('DELETE FROM pending_rate_notifications')
    );
    expect(rateCleanup).toBeTruthy();
  });
});
