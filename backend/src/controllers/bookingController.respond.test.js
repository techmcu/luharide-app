/**
 * Respond to booking (accept/reject) — SOP BL-024→026, D-030→031
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
const { respondToBooking } = require('./bookingController');

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
    status: 'pending',
    seat_numbers: [2, 3],
    available_seats: 3,
    departure_time: futureISO,
    ...overrides,
  };
}

describe('respondToBooking', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
    pool.query.mockResolvedValue({ rows: [] });
  });

  // ── Invalid action ────────────────────────────────────────────────────────
  it('rejects invalid action (not accept/reject)', async () => {
    const req = { params: { id: BOOK_ID }, body: { action: 'foo' }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    respondToBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  // ── Booking not found ─────────────────────────────────────────────────────
  it('returns 404 when booking not found', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })   // BEGIN
      .mockResolvedValueOnce({ rows: [] });  // SELECT — empty

    const req = { params: { id: BOOK_ID }, body: { action: 'accept' }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    respondToBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 404 })
    );
  });

  // ── Wrong driver ──────────────────────────────────────────────────────────
  it('rejects response from wrong driver', async () => {
    const booking = makeBooking();

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] });

    const req = { params: { id: BOOK_ID }, body: { action: 'accept' }, user: { id: 'x0000000-0000-0000-0000-000000000099' } };
    const next = jest.fn();
    respondToBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 403 })
    );
  });

  // ── Not pending ───────────────────────────────────────────────────────────
  it('rejects response for non-pending booking', async () => {
    const booking = makeBooking({ status: 'confirmed' });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] });

    const req = { params: { id: BOOK_ID }, body: { action: 'accept' }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    respondToBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  // ── SOP BL-024: Accept after departure blocked ────────────────────────────
  it('rejects accept after departure time passed', async () => {
    const booking = makeBooking({ departure_time: pastISO });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] });

    const req = { params: { id: BOOK_ID }, body: { action: 'accept' }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    respondToBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  // ── SOP BL-025: Reject after departure blocked ────────────────────────────
  it('rejects reject after departure time passed', async () => {
    const booking = makeBooking({ departure_time: pastISO });

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] });

    const req = { params: { id: BOOK_ID }, body: { action: 'reject' }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    respondToBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  // ── SOP D-031: Reject restores seats ──────────────────────────────────────
  it('restores seats when driver rejects', async () => {
    const booking = makeBooking();

    client.query
      .mockResolvedValueOnce({ rows: [] })          // BEGIN
      .mockResolvedValueOnce({ rows: [booking] })   // SELECT booking FOR UPDATE
      .mockResolvedValueOnce({ rows: [] })           // UPDATE status=cancelled
      .mockResolvedValueOnce({ rows: [] })           // UPDATE available_seats +
      .mockResolvedValueOnce({ rows: [] });          // COMMIT

    const req = { params: { id: BOOK_ID }, body: { action: 'reject' }, user: { id: DRIVER_ID } };
    respondToBooking(req, mockRes(), jest.fn());
    await flush();

    const restore = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('available_seats = available_seats +')
    );
    expect(restore).toBeTruthy();
    expect(restore[1]).toEqual([2, TRIP_ID]);
  });

  // ── SOP BL-026: Reject sends notification to passenger ────────────────────
  it('notifies passenger when booking rejected', async () => {
    const booking = makeBooking();

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });

    pool.query.mockResolvedValueOnce({
      rows: [{ id: 'n1', user_id: PASS_ID, type: 'booking_rejected' }],
    });

    const req = { params: { id: BOOK_ID }, body: { action: 'reject' }, user: { id: DRIVER_ID } };
    respondToBooking(req, mockRes(), jest.fn());
    await flush();

    const notifInsert = pool.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('booking_rejected')
    );
    expect(notifInsert).toBeTruthy();
  });

  // ── SOP D-030: Accept booking confirms it ─────────────────────────────────
  it('confirms booking when driver accepts', async () => {
    const booking = makeBooking();

    client.query
      .mockResolvedValueOnce({ rows: [] })                        // BEGIN
      .mockResolvedValueOnce({ rows: [booking] })                 // SELECT booking FOR UPDATE
      .mockResolvedValueOnce({ rows: [{ available_seats: 3 }] })  // SELECT trip FOR UPDATE
      .mockResolvedValueOnce({ rows: [] })                        // SELECT confirmed bookings
      .mockResolvedValueOnce({ rows: [] })                        // UPDATE status=confirmed
      .mockResolvedValueOnce({ rows: [] })                        // SELECT other pending
      .mockResolvedValueOnce({ rows: [] });                       // COMMIT

    pool.query
      .mockResolvedValueOnce({ rows: [{ id: 'n1', user_id: PASS_ID }] })  // accept notification
      .mockResolvedValueOnce({ rows: [] });  // rate notification insert

    const req = { params: { id: BOOK_ID }, body: { action: 'accept' }, user: { id: DRIVER_ID } };
    const res = mockRes();
    respondToBooking(req, res, jest.fn());
    await flush();

    const confirmUpdate = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes("status = 'confirmed'")
    );
    expect(confirmUpdate).toBeTruthy();
  });

  // ── Invalid UUID ──────────────────────────────────────────────────────────
  it('rejects invalid booking UUID', async () => {
    const req = { params: { id: 'not-uuid' }, body: { action: 'accept' }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    respondToBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });
});
