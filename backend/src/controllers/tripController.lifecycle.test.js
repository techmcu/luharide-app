/**
 * Trip creation validation + start/complete/delete edge cases
 * SOP: BL-002→005, BL-027→028, D-028, D-028B
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
const { createTrip, startTrip, completeTrip, deleteTrip } = require('./tripController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const TRIP_ID   = 'a0000000-0000-0000-0000-000000000001';
const DRIVER_ID = 'b0000000-0000-0000-0000-000000000001';

const futureISO = new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();
const soon15min = new Date(Date.now() + 15 * 60 * 1000).toISOString();

const verif = { vehicle_capacity: 7, vehicle_registration: 'UK07-1234' };

function setupCreateMocks(overrides = {}) {
  pool.query
    .mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] })  // block check
    .mockResolvedValueOnce({ rows: [overrides.verif || verif] })        // verification
    .mockResolvedValueOnce({ rows: [{ vehicle_model_id: null }] })      // model
    .mockResolvedValueOnce({ rows: overrides.overlap || [] })           // overlap check
    .mockResolvedValueOnce({ rows: [{ cnt: 0 }] })                     // daily ride limit
    .mockResolvedValueOnce({ rows: [{ id: TRIP_ID, status: 'scheduled' }] }); // INSERT
}

const validBody = { from_location: 'Dehradun', to_location: 'Purola', departure_time: futureISO, fare_per_seat: 500, estimated_duration_hours: 3 };

describe('createTrip — validation', () => {
  beforeEach(() => jest.clearAllMocks());

  // ── SOP BL-002: Same from-to block ────────────────────────────────────────
  it('rejects same from and to location', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] });

    const req = {
      body: { ...validBody, from_location: 'Dehradun', to_location: 'Dehradun' },
      user: { id: DRIVER_ID }, headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-003: Overlapping rides block ───────────────────────────────────
  it('rejects overlapping scheduled ride', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] })
      .mockResolvedValueOnce({ rows: [verif] })
      .mockResolvedValueOnce({ rows: [{ vehicle_model_id: null }] })
      .mockResolvedValueOnce({ rows: [{ id: 'existing-trip' }] }); // overlap found

    const req = {
      body: { ...validBody },
      user: { id: DRIVER_ID }, headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-004: Fare minimum ₹10 ─────────────────────────────────────────
  it('rejects fare below ₹10', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] })
      .mockResolvedValueOnce({ rows: [verif] })
      .mockResolvedValueOnce({ rows: [{ vehicle_model_id: null }] })
      .mockResolvedValueOnce({ rows: [] }) // overlap
      .mockResolvedValueOnce({ rows: [{ cnt: 0 }] }); // daily ride limit

    const req = {
      body: { ...validBody, fare_per_seat: 5 },
      user: { id: DRIVER_ID }, headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── SOP BL-005: Fare maximum ₹10000 ──────────────────────────────────────
  it('rejects fare above ₹10000', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] })
      .mockResolvedValueOnce({ rows: [verif] })
      .mockResolvedValueOnce({ rows: [{ vehicle_model_id: null }] })
      .mockResolvedValueOnce({ rows: [] }) // overlap
      .mockResolvedValueOnce({ rows: [{ cnt: 0 }] }); // daily ride limit

    const req = {
      body: { ...validBody, fare_per_seat: 15000 },
      user: { id: DRIVER_ID }, headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── 30-min advance minimum ────────────────────────────────────────────────
  it('rejects departure less than 30 minutes away', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] })
      .mockResolvedValueOnce({ rows: [verif] })
      .mockResolvedValueOnce({ rows: [{ vehicle_model_id: null }] });

    const req = {
      body: { ...validBody, departure_time: soon15min },
      user: { id: DRIVER_ID }, headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── Cancel-blocked driver can't create ────────────────────────────────────
  it('rejects creation when driver is cancel-blocked', async () => {
    const futureBlock = new Date(Date.now() + 60 * 60 * 1000).toISOString();
    pool.query.mockResolvedValueOnce({ rows: [{ cancel_blocked_until: futureBlock }] });

    const req = {
      body: { ...validBody },
      user: { id: DRIVER_ID }, headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── Unverified driver rejected ────────────────────────────────────────────
  it('rejects unverified driver', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ cancel_blocked_until: null }] })
      .mockResolvedValueOnce({ rows: [] }); // no verification

    const req = {
      body: { ...validBody },
      user: { id: DRIVER_ID }, headers: {},
    };
    const next = jest.fn();
    createTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
  });

  // ── Successful creation ───────────────────────────────────────────────────
  it('creates trip with valid data', async () => {
    setupCreateMocks();

    const req = {
      body: { ...validBody },
      user: { id: DRIVER_ID }, headers: {},
    };
    const res = mockRes();
    createTrip(req, res, jest.fn());
    await flush();

    const insertCall = pool.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('INSERT INTO trips')
    );
    expect(insertCall).toBeTruthy();
  });
});

// ── SOP BL-027: Start trip ──────────────────────────────────────────────────
describe('startTrip', () => {
  let client;
  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('rejects start for completed trip', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ id: TRIP_ID, status: 'completed', driver_id: DRIVER_ID }] });

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    startTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects start for cancelled trip', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ id: TRIP_ID, status: 'cancelled', driver_id: DRIVER_ID }] });

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    startTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });
});

// ── SOP BL-028: Complete trip ───────────────────────────────────────────────
describe('completeTrip', () => {
  let client;
  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('rejects complete for scheduled trip before departure', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{
        id: TRIP_ID, status: 'scheduled', driver_id: DRIVER_ID,
        departure_time: futureISO,
      }] });

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    completeTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });
});

// ── SOP D-028, D-028B: Delete trip ──────────────────────────────────────────
describe('deleteTrip', () => {
  let client;
  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  // D-028: Has bookings → blocked
  it('rejects delete when trip has active bookings', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{
        id: TRIP_ID, status: 'scheduled', driver_id: DRIVER_ID,
        departure_time: futureISO,
      }] })
      .mockResolvedValueOnce({ rows: [{ count: '2' }] }); // active bookings

    const req = { params: { id: TRIP_ID }, user: { id: DRIVER_ID } };
    const next = jest.fn();
    deleteTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // Wrong driver
  it('rejects delete by wrong driver', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] }); // no trip for this driver

    const req = { params: { id: TRIP_ID }, user: { id: 'x0000000-0000-0000-0000-000000000099' } };
    const next = jest.fn();
    deleteTrip(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 404 }));
  });
});
