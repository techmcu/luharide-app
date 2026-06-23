/**
 * seatLockController — driver reserves/releases their own unbooked seats.
 * SOP P-067→P-072. DB + socket are mocked; no real database connection.
 */

jest.mock('../../config/database', () => ({
  pool: { connect: jest.fn(), query: jest.fn() },
}));
jest.mock('../../socket/realtimeEmitter', () => ({
  emitTripUpdated: jest.fn(),
}));
jest.mock('../../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { pool } = require('../../config/database');
const { lockSeats, unlockSeats } = require('./seatLockController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const TRIP_ID   = 'a0000000-0000-0000-0000-000000000001';
const DRIVER_ID = 'b0000000-0000-0000-0000-000000000001';

const futureISO = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
const pastISO   = new Date(Date.now() - 60000).toISOString();

function makeTrip(overrides = {}) {
  return {
    id: TRIP_ID,
    status: 'scheduled',
    departure_time: futureISO,
    available_seats: 5,
    total_seats: 7,
    ...overrides,
  };
}

describe('lockSeats', () => {
  let client;
  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
    pool.query.mockResolvedValue({ rows: [] });
  });

  it('locks a free seat and reports it back', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })                     // BEGIN
      .mockResolvedValueOnce({ rows: [makeTrip()] })           // SELECT trip FOR UPDATE
      .mockResolvedValueOnce({ rows: [] })                     // SELECT bookings
      .mockResolvedValueOnce({ rows: [] })                     // SELECT existing locks
      .mockResolvedValueOnce({ rowCount: 1 })                  // INSERT lock
      .mockResolvedValueOnce({ rows: [] })                     // UPDATE available_seats
      .mockResolvedValueOnce({ rows: [] });                    // COMMIT
    pool.query.mockResolvedValueOnce({ rows: [{ seat_number: 3 }] }); // final locked read

    const req = { params: { id: TRIP_ID }, body: { seat_numbers: [3], note: 'bhai' }, user: { id: DRIVER_ID } };
    const res = mockRes();
    const next = jest.fn();
    lockSeats(req, res, next);
    await flush();

    expect(next).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalled();
  });

  it('rejects locking seat 1 (driver seat)', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })             // BEGIN
      .mockResolvedValueOnce({ rows: [makeTrip()] });  // SELECT trip
    const req = { params: { id: TRIP_ID }, body: { seat_numbers: [1] }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    lockSeats(req, mockRes(), next);
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects locking a seat already booked by a passenger', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })                          // BEGIN
      .mockResolvedValueOnce({ rows: [makeTrip()] })                // SELECT trip
      .mockResolvedValueOnce({ rows: [{ seat_numbers: [3] }] });    // SELECT bookings — seat 3 taken
    const req = { params: { id: TRIP_ID }, body: { seat_numbers: [3] }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    lockSeats(req, mockRes(), next);
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects when caller is not the trip driver (no row)', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })   // BEGIN
      .mockResolvedValueOnce({ rows: [] });  // SELECT trip — none owned by caller
    const req = { params: { id: TRIP_ID }, body: { seat_numbers: [3] }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    lockSeats(req, mockRes(), next);
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 404 }));
  });

  it('rejects locking on a departed ride', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })                                  // BEGIN
      .mockResolvedValueOnce({ rows: [makeTrip({ departure_time: pastISO })] }); // SELECT trip
    const req = { params: { id: TRIP_ID }, body: { seat_numbers: [3] }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    lockSeats(req, mockRes(), next);
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects an empty seat_numbers payload', async () => {
    const req = { params: { id: TRIP_ID }, body: { seat_numbers: [] }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    lockSeats(req, mockRes(), next);
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });
});

describe('unlockSeats', () => {
  let client;
  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
    pool.query.mockResolvedValue({ rows: [] });
  });

  it('releases a reserved seat', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })                                      // BEGIN
      .mockResolvedValueOnce({ rows: [{ status: 'scheduled', total_seats: 7 }] }) // SELECT trip
      .mockResolvedValueOnce({ rowCount: 1, rows: [{ seat_number: 3 }] })       // DELETE
      .mockResolvedValueOnce({ rows: [] })                                      // UPDATE available_seats
      .mockResolvedValueOnce({ rows: [] });                                     // COMMIT
    const req = { params: { id: TRIP_ID }, body: { seat_numbers: [3] }, user: { id: DRIVER_ID } };
    const res = mockRes();
    const next = jest.fn();
    unlockSeats(req, res, next);
    await flush();
    expect(next).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalled();
  });

  it('rejects when caller is not the trip driver', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })   // BEGIN
      .mockResolvedValueOnce({ rows: [] });  // SELECT trip — none
    const req = { params: { id: TRIP_ID }, body: { seat_numbers: [3] }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    unlockSeats(req, mockRes(), next);
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 404 }));
  });
});
