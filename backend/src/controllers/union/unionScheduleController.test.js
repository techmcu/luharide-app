/**
 * Union schedule creation — SOP U-010→012
 * DB is mocked — no real database connection.
 */

jest.mock('../../config/database', () => ({
  pool: { query: jest.fn(), connect: jest.fn() },
}));
jest.mock('../../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));
jest.mock('../../utils/titleCase', () => jest.fn(s => s));
jest.mock('../../utils/pushNotification', () => ({
  sendPushToMultipleUsers: jest.fn().mockResolvedValue(),
}));
jest.mock('../../services/olaMapsService', () => ({
  isValidLatLng: jest.fn(() => true),
  geocode: jest.fn().mockResolvedValue(null),
  getRouteDistance: jest.fn().mockResolvedValue(null),
}));

const { pool } = require('../../config/database');
const olaMaps = require('../../services/olaMapsService');
const { createUnionSchedulesBulk } = require('./unionScheduleController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const ADMIN_ID  = 'a0000000-0000-0000-0000-000000000001';
const UNION_ID  = 'c0000000-0000-0000-0000-000000000001';
const DRIVER_ID = 'd0000000-0000-0000-0000-000000000001';

describe('createUnionSchedulesBulk', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('rejects empty driver list', async () => {
    const req = {
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: [] },
      user: { id: ADMIN_ID },
    };
    const next = jest.fn();
    createUnionSchedulesBulk(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects more than 50 drivers', async () => {
    const ids = Array.from({ length: 51 }, (_, i) => `d000-${i}`);
    const req = {
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: ids },
      user: { id: ADMIN_ID },
    };
    const next = jest.fn();
    createUnionSchedulesBulk(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects when no approved union found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] }); // no union

    const req = {
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: [DRIVER_ID] },
      user: { id: ADMIN_ID },
    };
    const next = jest.fn();
    createUnionSchedulesBulk(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
  });

  it('rejects when daily limit reached', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: UNION_ID, union_name: 'Test', fcm_enabled: false }] })
      .mockResolvedValueOnce({ rows: [{ cnt: 3 }] }); // daily limit hit

    const req = {
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: [DRIVER_ID] },
      user: { id: ADMIN_ID },
    };
    const next = jest.fn();
    createUnionSchedulesBulk(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects invalid driver IDs for this union', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: UNION_ID, union_name: 'Test', fcm_enabled: false }] })
      .mockResolvedValueOnce({ rows: [{ cnt: 0 }] })     // daily count
      .mockResolvedValueOnce({ rows: [] });                // driver check — mismatch

    const req = {
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: [DRIVER_ID] },
      user: { id: ADMIN_ID },
    };
    const next = jest.fn();
    createUnionSchedulesBulk(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  // ── Bulk creation success (the multi-driver / multi-ride-per-day path) ──────
  function setupSuccess({ cnt = 1, driverIds = [DRIVER_ID] } = {}) {
    // Main path: union lookup -> daily count -> driver check. Background geo
    // UPDATEs reuse the same pool.query mock (default below).
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: UNION_ID, union_name: 'Test', fcm_enabled: false }] })
      .mockResolvedValueOnce({ rows: [{ cnt }] })
      .mockResolvedValueOnce({ rows: driverIds.map(id => ({ id })) })
      .mockResolvedValue({ rows: [] }); // background geo-persist UPDATEs (best-effort)
    const created = driverIds.map((id, i) => ({ id: `s-${i}`, union_driver_id: id }));
    client.query
      .mockResolvedValueOnce({ rows: [] })        // BEGIN
      .mockResolvedValueOnce({ rows: created })   // INSERT ... RETURNING *
      .mockResolvedValueOnce({ rows: [] })        // daily action INSERT
      .mockResolvedValueOnce({ rows: [] });       // COMMIT
    return created;
  }

  it('creates rides for many drivers in one publish and responds 201', async () => {
    const driverIds = Array.from({ length: 8 }, (_, i) => `d000-${i}`);
    setupSuccess({ cnt: 0, driverIds }); // cnt 0 → first ride of day path too
    const res = mockRes();
    const next = jest.fn();
    createUnionSchedulesBulk({
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: driverIds },
      user: { id: ADMIN_ID },
    }, res, next);
    await flush();

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(201);
    const payload = res.json.mock.calls[0][0];
    expect(payload.data.count).toBe(8);
    expect(payload.data.schedules).toHaveLength(8);
  });

  // ── REGRESSION (no side-effects): a slow/failing Ola Maps geocode/route must
  //    NOT block or fail ride creation — it now runs in the background. ─────────
  it('still responds 201 when the Ola Maps route lookup throws', async () => {
    setupSuccess({ cnt: 1 });
    olaMaps.getRouteDistance.mockRejectedValueOnce(new Error('ola maps timeout'));
    olaMaps.geocode.mockRejectedValueOnce(new Error('ola maps down'));
    const res = mockRes();
    const next = jest.fn();
    createUnionSchedulesBulk({
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: [DRIVER_ID] },
      user: { id: ADMIN_ID },
    }, res, next);
    await flush();
    await flush(); // let background geo enrichment settle (and swallow its error)

    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json.mock.calls[0][0].data.count).toBe(1);
  });
});
