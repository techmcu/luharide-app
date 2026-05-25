/**
 * Booking seat-counting logic: pending bookings MUST reserve (decrement) seats,
 * and reject / cancel / auto-cancel MUST restore them.
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
const { createBooking, respondToBooking, cancelBooking } = require('./bookingController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}

// asyncHandler doesn't return the promise, so we must flush microtasks
const flush = () => new Promise(r => setImmediate(r));

describe('createBooking — seat reservation', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
    pool.query.mockResolvedValue({ rows: [] });
  });

  function setupClientQueries(overrides = {}) {
    const trip = {
      id: 'trip-1', driver_id: 'driver-1', fare_per_seat: '100',
      total_seats: 7, total_capacity: 7, available_seats: 5,
      require_approval: overrides.require_approval ?? true,
    };
    const booking = {
      id: 'b-1', trip_id: 'trip-1', seat_numbers: [2, 3],
      status: trip.require_approval ? 'pending' : 'confirmed',
      total_amount: '200', created_at: new Date(),
    };
    // Query sequence for createBooking (no idempotency key):
    // 1. BEGIN
    // 2. cooldown check
    // 3. SELECT trip FOR UPDATE
    // 4. existing bookings check
    // 5. INSERT booking
    // 6. UPDATE available_seats
    // 7. (if confirmed) UPDATE confirmed_at
    // 8. COMMIT
    const mocks = [
      { rows: [] },             // BEGIN
      { rows: [] },             // cooldown check
      { rows: [trip] },         // SELECT trip FOR UPDATE
      { rows: [] },             // existing bookings
      { rows: [booking] },      // INSERT booking
      { rows: [] },             // UPDATE available_seats
    ];
    if (!trip.require_approval) {
      mocks.push({ rows: [] }); // UPDATE confirmed_at
    }
    mocks.push({ rows: [] });   // COMMIT
    for (const m of mocks) {
      client.query.mockResolvedValueOnce(m);
    }
    return { trip, booking };
  }

  it('decrements available_seats for PENDING bookings', async () => {
    setupClientQueries({ require_approval: true });

    const req = { body: { trip_id: 'trip-1', seat_numbers: [2, 3] }, user: { id: 'p-1' }, headers: {} };
    createBooking(req, mockRes(), jest.fn());
    await flush();

    const seatUpdate = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('available_seats = available_seats -')
    );
    expect(seatUpdate).toBeTruthy();
    expect(seatUpdate[1]).toEqual([2, 'trip-1']);
  });

  it('decrements available_seats for CONFIRMED bookings', async () => {
    setupClientQueries({ require_approval: false });

    const req = { body: { trip_id: 'trip-1', seat_numbers: [2, 3] }, user: { id: 'p-1' }, headers: {} };
    createBooking(req, mockRes(), jest.fn());
    await flush();

    const seatUpdate = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('available_seats = available_seats -')
    );
    expect(seatUpdate).toBeTruthy();
  });
});

describe('respondToBooking — reject restores seats', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
    pool.query.mockResolvedValue({ rows: [] });
  });

  it('restores available_seats when driver rejects a pending booking', async () => {
    const booking = {
      id: 'b-1', trip_id: 'trip-1', passenger_id: 'p-1', driver_id: 'driver-1',
      status: 'pending', seat_numbers: [2, 3], available_seats: 3,
      departure_time: new Date(Date.now() + 86400000).toISOString(),
    };
    // Query sequence for respondToBooking (reject):
    // 1. BEGIN
    // 2. SELECT booking JOIN trip FOR UPDATE
    // 3. UPDATE status=cancelled
    // 4. UPDATE available_seats +
    // 5. COMMIT
    client.query
      .mockResolvedValueOnce({ rows: [] })          // BEGIN
      .mockResolvedValueOnce({ rows: [booking] })   // SELECT booking FOR UPDATE
      .mockResolvedValueOnce({ rows: [] })           // UPDATE status=cancelled
      .mockResolvedValueOnce({ rows: [] })           // UPDATE available_seats +
      .mockResolvedValueOnce({ rows: [] })           // COMMIT
      ;

    const req = { params: { id: 'b-1' }, body: { action: 'reject' }, user: { id: 'driver-1' } };
    respondToBooking(req, mockRes(), jest.fn());
    await flush();

    const restore = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('available_seats = available_seats +')
    );
    expect(restore).toBeTruthy();
    expect(restore[1]).toEqual([2, 'trip-1']);
  });
});

describe('cancelBooking — restores seats for any status', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
    pool.query.mockResolvedValue({ rows: [] });
  });

  it('restores seats when cancelling a PENDING booking', async () => {
    const booking = {
      id: 'b-1', trip_id: 'trip-1', passenger_id: 'p-1', driver_id: 'driver-1',
      status: 'pending', seat_numbers: [4, 5],
      departure_time: new Date(Date.now() + 86400000).toISOString(),
    };
    // Query sequence for cancelBooking:
    // 1. BEGIN
    // 2. SELECT booking JOIN trip FOR UPDATE
    // 3. UPDATE status=cancelled
    // 4. UPDATE available_seats +
    // 5. COMMIT
    client.query
      .mockResolvedValueOnce({ rows: [] })          // BEGIN
      .mockResolvedValueOnce({ rows: [booking] })   // SELECT booking FOR UPDATE
      .mockResolvedValueOnce({ rows: [] })           // UPDATE status=cancelled
      .mockResolvedValueOnce({ rows: [] })           // UPDATE available_seats +
      .mockResolvedValueOnce({ rows: [] })           // COMMIT
      ;

    const req = { params: { id: 'b-1' }, body: {}, user: { id: 'p-1' } };
    cancelBooking(req, mockRes(), jest.fn());
    await flush();

    const restore = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('available_seats = available_seats +')
    );
    expect(restore).toBeTruthy();
    expect(restore[1]).toEqual([2, 'trip-1']);
  });

  it('restores seats when cancelling a CONFIRMED booking', async () => {
    const booking = {
      id: 'b-2', trip_id: 'trip-1', passenger_id: 'p-1', driver_id: 'driver-1',
      status: 'confirmed', seat_numbers: [2],
      departure_time: new Date(Date.now() + 86400000).toISOString(),
    };
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [booking] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      ;

    const req = { params: { id: 'b-2' }, body: {}, user: { id: 'p-1' } };
    cancelBooking(req, mockRes(), jest.fn());
    await flush();

    const restore = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('available_seats = available_seats +')
    );
    expect(restore).toBeTruthy();
    expect(restore[1]).toEqual([1, 'trip-1']);
  });
});
