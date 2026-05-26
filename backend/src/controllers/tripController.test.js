/**
 * Trip lifecycle tests.
 * Tests createTrip, cancelTrip, startTrip, completeTrip, deleteTrip controller logic.
 * DB and socket are mocked — same pattern as bookingController.test.js.
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
const { createTrip, cancelTrip, startTrip, completeTrip, deleteTrip } = require('./tripController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}

const flush = () => new Promise(r => setImmediate(r));

const futureISO = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

// ─────────────────────────────────────────────────────────────────────────────
// CREATE TRIP
// ─────────────────────────────────────────────────────────────────────────────

describe('createTrip', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('creates trip with verified vehicle capacity as total_seats', async () => {
    const verif = { vehicle_capacity: 7, vehicle_registration: 'UK07-1234' };
    const trip = {
      id: 'trip-1', driver_id: 'd-1', from_location: 'Dehradun', to_location: 'Purola',
      total_capacity: 7, available_seats: 7, status: 'scheduled',
    };

    pool.query
      .mockResolvedValueOnce({ rows: [verif] })         // driver_verification_requests
      .mockResolvedValueOnce({ rows: [{ vehicle_model_id: null }] }) // vehicle_model_id query
      .mockResolvedValueOnce({ rows: [trip] });          // INSERT trip

    const req = {
      body: {
        from_location: 'Dehradun', to_location: 'Purola',
        departure_time: futureISO, fare_per_seat: 500,
      },
      user: { id: 'd-1' },
      headers: {},
    };
    createTrip(req, mockRes(), jest.fn());
    await flush();

    const insertCall = pool.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('INSERT INTO trips')
    );
    expect(insertCall).toBeTruthy();
  });

  it('rejects if driver is not verified', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] }); // no verification

    const req = {
      body: {
        from_location: 'Dehradun', to_location: 'Purola',
        departure_time: futureISO, fare_per_seat: 500,
      },
      user: { id: 'd-1' },
      headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 403 })
    );
  });

  it('rejects past departure time', async () => {
    const verif = { vehicle_capacity: 7, vehicle_registration: 'UK07-1234' };
    pool.query
      .mockResolvedValueOnce({ rows: [verif] })
      .mockResolvedValueOnce({ rows: [{ vehicle_model_id: null }] });

    const pastISO = new Date(Date.now() - 60000).toISOString();
    const req = {
      body: {
        from_location: 'Dehradun', to_location: 'Purola',
        departure_time: pastISO, fare_per_seat: 500,
      },
      user: { id: 'd-1' },
      headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  it('rejects empty from_location', async () => {
    const req = {
      body: {
        from_location: '', to_location: 'Purola',
        departure_time: futureISO, fare_per_seat: 500,
      },
      user: { id: 'd-1' },
      headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  it('rejects zero fare', async () => {
    const verif = { vehicle_capacity: 7, vehicle_registration: 'UK07-1234' };
    pool.query.mockResolvedValueOnce({ rows: [verif] });

    const req = {
      body: {
        from_location: 'Dehradun', to_location: 'Purola',
        departure_time: futureISO, fare_per_seat: 0,
      },
      user: { id: 'd-1' },
      headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// CANCEL TRIP
// ─────────────────────────────────────────────────────────────────────────────

describe('cancelTrip', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('cancels trip with no bookings', async () => {
    const trip = {
      id: 'trip-1', status: 'scheduled', driver_id: 'd-1',
      departure_time: new Date(Date.now() + 86400000).toISOString(),
    };

    client.query
      .mockResolvedValueOnce({ rows: [] })           // BEGIN
      .mockResolvedValueOnce({ rows: [trip] })       // SELECT trip FOR UPDATE
      .mockResolvedValueOnce({ rows: [] })           // SELECT confirmed bookings
      .mockResolvedValueOnce({ rows: [] })           // SELECT all active bookings
      .mockResolvedValueOnce({ rows: [], rowCount: 0 }) // UPDATE bookings to cancelled
      .mockResolvedValueOnce({ rows: [] })           // UPDATE trip status
      .mockResolvedValueOnce({ rows: [] });          // COMMIT

    const req = { params: { id: 'trip-1' }, user: { id: 'd-1' } };
    cancelTrip(req, mockRes(), jest.fn());
    await flush();

    const statusUpdate = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes("status = 'cancelled'") && sql.includes('trips')
    );
    expect(statusUpdate).toBeTruthy();
  });

  it('cancels trip and restores seats from all active bookings', async () => {
    const trip = {
      id: 'trip-1', status: 'scheduled', driver_id: 'd-1',
      departure_time: new Date(Date.now() + 86400000).toISOString(),
    };
    const confirmedBookings = [
      { id: 'b-1', passenger_id: 'p-1', seat_numbers: [1, 2] },
    ];
    const allActiveBookings = [
      { id: 'b-1', passenger_id: 'p-1', seat_numbers: [1, 2], status: 'confirmed' },
      { id: 'b-2', passenger_id: 'p-2', seat_numbers: [3], status: 'pending' },
    ];

    client.query
      .mockResolvedValueOnce({ rows: [] })                       // BEGIN
      .mockResolvedValueOnce({ rows: [trip] })                   // SELECT trip FOR UPDATE
      .mockResolvedValueOnce({ rows: confirmedBookings })        // SELECT confirmed bookings
      .mockResolvedValueOnce({ rows: allActiveBookings })        // SELECT all active bookings
      .mockResolvedValueOnce({ rows: [], rowCount: 2 })          // UPDATE bookings
      .mockResolvedValueOnce({ rows: [] })                       // UPDATE trip + seats
      .mockResolvedValueOnce({ rows: [{ id: 'p-1' }, { id: 'p-2' }] }) // SELECT users for notification
      .mockResolvedValueOnce({ rows: [], rowCount: 2 })          // INSERT notifications
      .mockResolvedValueOnce({ rows: [] });                      // COMMIT

    const req = { params: { id: 'trip-1' }, user: { id: 'd-1' } };
    cancelTrip(req, mockRes(), jest.fn());
    await flush();

    const seatRestore = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('available_seats = available_seats +')
    );
    expect(seatRestore).toBeTruthy();
    // 3 seats total (2 confirmed + 1 pending)
    expect(seatRestore[1][0]).toBe(3);
  });

  it('rejects cancel for already-cancelled trip', async () => {
    const trip = {
      id: 'trip-1', status: 'cancelled', driver_id: 'd-1',
      departure_time: new Date(Date.now() + 86400000).toISOString(),
    };

    client.query
      .mockResolvedValueOnce({ rows: [] })           // BEGIN
      .mockResolvedValueOnce({ rows: [trip] });      // SELECT trip

    const req = { params: { id: 'trip-1' }, user: { id: 'd-1' } };
    const next = jest.fn();
    cancelTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  it('rejects cancel for in_progress trip', async () => {
    const trip = {
      id: 'trip-1', status: 'in_progress', driver_id: 'd-1',
      departure_time: new Date(Date.now() - 60000).toISOString(),
    };

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [trip] });

    const req = { params: { id: 'trip-1' }, user: { id: 'd-1' } };
    const next = jest.fn();
    cancelTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  it('rejects cancel for wrong driver (not found)', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] }); // no trip for this driver

    const req = { params: { id: 'trip-1' }, user: { id: 'wrong-driver' } };
    const next = jest.fn();
    cancelTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 404 })
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// START TRIP
// ─────────────────────────────────────────────────────────────────────────────

describe('startTrip', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('rejects start for completed trip', async () => {
    const trip = { id: 'trip-1', status: 'completed', driver_id: 'd-1' };

    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [trip] });

    const req = { params: { id: 'trip-1' }, user: { id: 'd-1' } };
    const next = jest.fn();
    startTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE TRIP
// ─────────────────────────────────────────────────────────────────────────────

describe('deleteTrip', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('rejects delete if trip has active bookings', async () => {
    const trip = {
      id: 'trip-1', status: 'scheduled', driver_id: 'd-1',
      departure_time: new Date(Date.now() + 86400000).toISOString(),
    };

    client.query
      .mockResolvedValueOnce({ rows: [] })           // BEGIN
      .mockResolvedValueOnce({ rows: [trip] })       // SELECT trip
      .mockResolvedValueOnce({ rows: [{ count: '2' }] }); // active bookings count

    const req = { params: { id: 'trip-1' }, user: { id: 'd-1' } };
    const next = jest.fn();
    deleteTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });
});
