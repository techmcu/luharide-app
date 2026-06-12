/**
 * createBooking edge cases — SOP BL-006→010, P-031→033
 * DB and socket are mocked — no real database connection.
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
const { createBooking } = require('./bookingController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const TRIP_ID   = 'a0000000-0000-0000-0000-000000000001';
const DRIVER_ID = 'b0000000-0000-0000-0000-000000000001';
const PASS_ID   = 'c0000000-0000-0000-0000-000000000001';

const futureISO = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
const pastISO   = new Date(Date.now() - 60000).toISOString();

function makeTrip(overrides = {}) {
  return {
    id: TRIP_ID,
    driver_id: DRIVER_ID,
    status: 'scheduled',
    departure_time: futureISO,
    fare_per_seat: 500,
    total_seats: 7,
    available_seats: 5,
    require_approval: true,
    created_source: 'union',
    ...overrides,
  };
}

describe('createBooking — edge cases', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
    pool.query.mockResolvedValue({ rows: [{ cancel_blocked_until: null }] });
  });

  // ── Missing fields ────────────────────────────────────────────────────────
  it('rejects when trip_id or seat_numbers missing', async () => {
    const req = { body: {}, user: { id: PASS_ID }, headers: {} };
    const next = jest.fn();
    createBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-006: Departed ride → can't book ───────────────────────────────
  it('rejects booking on departed ride', async () => {
    const trip = makeTrip({ departure_time: pastISO });

    client.query
      .mockResolvedValueOnce({ rows: [] })         // BEGIN
      .mockResolvedValueOnce({ rows: [] })         // cooldown
      .mockResolvedValueOnce({ rows: [trip] });    // SELECT trip FOR UPDATE

    const req = {
      body: { trip_id: TRIP_ID, seat_numbers: [2] },
      user: { id: PASS_ID }, headers: {},
    };
    const next = jest.fn();
    createBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-007: Driver can't book own trip ────────────────────────────────
  it('rejects driver booking own trip', async () => {
    const trip = makeTrip();

    client.query
      .mockResolvedValueOnce({ rows: [] })         // BEGIN
      .mockResolvedValueOnce({ rows: [] })         // cooldown
      .mockResolvedValueOnce({ rows: [trip] });    // SELECT trip

    const req = {
      body: { trip_id: TRIP_ID, seat_numbers: [2] },
      user: { id: DRIVER_ID }, headers: {},
    };
    const next = jest.fn();
    createBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP P-033: Duplicate active booking ───────────────────────────────────
  it('rejects duplicate active booking on same trip', async () => {
    const trip = makeTrip();

    client.query
      .mockResolvedValueOnce({ rows: [] })                          // BEGIN
      .mockResolvedValueOnce({ rows: [] })                          // cooldown
      .mockResolvedValueOnce({ rows: [trip] })                      // SELECT trip FOR UPDATE
      .mockResolvedValueOnce({ rows: [{ id: 'existing-booking' }] }); // dup check

    const req = {
      body: { trip_id: TRIP_ID, seat_numbers: [3] },
      user: { id: PASS_ID }, headers: {},
    };
    const next = jest.fn();
    createBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-009: Seat 1 reserved for driver ────────────────────────────────
  it('rejects seat 1 (driver seat)', async () => {
    const trip = makeTrip();

    client.query
      .mockResolvedValueOnce({ rows: [] })         // BEGIN
      .mockResolvedValueOnce({ rows: [] })         // cooldown
      .mockResolvedValueOnce({ rows: [trip] })     // SELECT trip
      .mockResolvedValueOnce({ rows: [] });        // dup check

    const req = {
      body: { trip_id: TRIP_ID, seat_numbers: [1] },
      user: { id: PASS_ID }, headers: {},
    };
    const next = jest.fn();
    createBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── Already booked seat ───────────────────────────────────────────────────
  it('rejects already booked seat', async () => {
    const trip = makeTrip();

    client.query
      .mockResolvedValueOnce({ rows: [] })                           // BEGIN
      .mockResolvedValueOnce({ rows: [] })                           // cooldown
      .mockResolvedValueOnce({ rows: [trip] })                       // SELECT trip
      .mockResolvedValueOnce({ rows: [] })                           // dup check
      .mockResolvedValueOnce({ rows: [{ seat_numbers: [2, 3] }] });  // existing bookings

    const req = {
      body: { trip_id: TRIP_ID, seat_numbers: [2] },
      user: { id: PASS_ID }, headers: {},
    };
    const next = jest.fn();
    createBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── Not enough seats ──────────────────────────────────────────────────────
  it('rejects when requesting more seats than available', async () => {
    const trip = makeTrip({ available_seats: 1 });

    client.query
      .mockResolvedValueOnce({ rows: [] })        // BEGIN
      .mockResolvedValueOnce({ rows: [] })        // cooldown
      .mockResolvedValueOnce({ rows: [trip] })    // SELECT trip
      .mockResolvedValueOnce({ rows: [] });       // dup check

    const req = {
      body: { trip_id: TRIP_ID, seat_numbers: [2, 3, 4] },
      user: { id: PASS_ID }, headers: {},
    };
    const next = jest.fn();
    createBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-010: Cooldown — re-book within 10 min of cancel ────────────────
  it('rejects booking within cooldown period after cancel', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })                        // BEGIN
      .mockResolvedValueOnce({ rows: [{ cancelled_at: new Date().toISOString() }] }); // cooldown match

    const req = {
      body: { trip_id: TRIP_ID, seat_numbers: [2] },
      user: { id: PASS_ID }, headers: {},
    };
    const next = jest.fn();
    createBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-008: Cancel-blocked user ───────────────────────────────────────
  it('rejects booking when user is cancel-blocked', async () => {
    const futureBlock = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    pool.query.mockResolvedValueOnce({ rows: [{ cancel_blocked_until: futureBlock }] });

    const req = {
      body: { trip_id: TRIP_ID, seat_numbers: [2] },
      user: { id: PASS_ID }, headers: {},
    };
    const next = jest.fn();
    createBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── Trip not found / not scheduled ────────────────────────────────────────
  it('returns 404 for non-existent or non-scheduled trip', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })   // BEGIN
      .mockResolvedValueOnce({ rows: [] })   // cooldown
      .mockResolvedValueOnce({ rows: [] });  // SELECT trip — empty

    const req = {
      body: { trip_id: TRIP_ID, seat_numbers: [2] },
      user: { id: PASS_ID }, headers: {},
    };
    const next = jest.fn();
    createBooking(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 404 }));
  });

  // ── Idempotency: duplicate request returns same booking ───────────────────
  it('returns existing booking for matching idempotency key', async () => {
    const existing = {
      id: 'b0000001', trip_id: TRIP_ID, seat_numbers: [2],
      status: 'pending', total_amount: 500, created_at: new Date(),
    };

    client.query
      .mockResolvedValueOnce({ rows: [] })            // BEGIN
      .mockResolvedValueOnce({ rows: [existing] })    // idempotency SELECT hit (before cooldown)
      .mockResolvedValueOnce({ rows: [] });           // COMMIT

    const req = {
      body: { trip_id: TRIP_ID, seat_numbers: [2] },
      user: { id: PASS_ID },
      headers: { 'idempotency-key': 'idem-123' },
    };
    const res = mockRes();
    createBooking(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
  });
});
