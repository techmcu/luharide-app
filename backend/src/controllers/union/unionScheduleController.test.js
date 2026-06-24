/**
 * Union schedule creation — SOP U-010→012
 * DB is mocked — no real database connection.
 *
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │ 🔒 RULE LOCKS — READ THIS IF CI FAILS HERE                                │
 * │                                                                           │
 * │ Agar GitHub CI laal (red) ho aur niche koi "RULE N: ..." test fail dikhe, │
 * │ matlab tumne us STABLE rule ko galti se tod diya. Test ka NAAM batata hai  │
 * │ kya toota. Niche map se code ki jagah dekho aur wahi theek karo:           │
 * │                                                                           │
 * │  RULE 1  Ek publish mein kam se kam 1 driver        → controller L16-18   │
 * │  RULE 2  Ek publish mein zyada se zyada 50 driver   → controller L19-21   │
 * │  RULE 3  Din mein sirf 3 baar publish               → controller L39-50   │
 * │  RULE 4  Ek publish = sirf 1 ginti (1 ya 50 driver) → controller L84-88   │
 * │  RULE 5  Notification sirf din ki PEHLI publish pe   → controller L102-105 │
 * │                                                                           │
 * │ Yeh rules JAANBOOJHKAR locked hain. Inhe badalna ho to PEHLE Rahul se      │
 * │ confirm karo, phir test bhi saath update karo — warna CI rokega.          │
 * └─────────────────────────────────────────────────────────────────────────┘
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
const { sendPushToMultipleUsers } = require('../../utils/pushNotification');
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

  it('RULE 1: ek publish mein kam se kam 1 driver zaroori (0 → reject)', async () => {
    const req = {
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: [] },
      user: { id: ADMIN_ID },
    };
    const next = jest.fn();
    createUnionSchedulesBulk(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('RULE 2: ek publish mein 50 se zyada driver allowed nahi (>50 → reject)', async () => {
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

  it('RULE 3: din mein 3 baar se zyada publish allowed nahi (4th → reject)', async () => {
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

  // ── REQUIREMENT LOCKS — these guard the stable union-ride rules. If a future
  //    change breaks any of them, CI fails BEFORE it ships. ─────────────────────

  // Routes pool.query / client.query by SQL content (order-independent), so the
  // background FCM + geo queries resolve correctly no matter when they run.
  function mockPoolBySql({ cnt = 0, fcmEnabled = true, globalEnabled = true, passengers = ['p1'] } = {}) {
    pool.query.mockImplementation((sql) => {
      const s = String(sql);
      if (s.includes('FROM union_admins')) {
        return Promise.resolve({ rows: [{ union_id: UNION_ID, union_name: 'Test', fcm_enabled: fcmEnabled }] });
      }
      if (s.includes('union_daily_actions') && s.includes('COUNT')) {
        return Promise.resolve({ rows: [{ cnt }] });
      }
      if (s.includes('FROM union_drivers')) {
        return Promise.resolve({ rows: [{ id: DRIVER_ID }] });
      }
      if (s.includes('fcm_global_union_rides')) {
        return Promise.resolve({ rows: [{ value: globalEnabled ? 'true' : 'false' }] });
      }
      if (s.includes("role = 'passenger'")) {
        return Promise.resolve({ rows: passengers.map((id) => ({ id })) });
      }
      return Promise.resolve({ rows: [] }); // geo UPDATEs etc.
    });
    client.query.mockImplementation((sql) => {
      const s = String(sql);
      if (s.includes('INSERT INTO union_schedules')) {
        return Promise.resolve({ rows: [{ id: 's-1', union_driver_id: DRIVER_ID }] });
      }
      return Promise.resolve({ rows: [] }); // BEGIN, daily-action INSERT, COMMIT
    });
  }

  const settle = async () => { for (let i = 0; i < 6; i++) await flush(); };

  // REQ 4: one publish == exactly ONE daily-action row, no matter the driver count.
  it('RULE 4: ek publish = sirf 1 ginti, chahe 1 ya 50 driver ho', async () => {
    const driverIds = Array.from({ length: 12 }, (_, i) => `d000-${i}`);
    setupSuccess({ cnt: 0, driverIds });
    createUnionSchedulesBulk({
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: driverIds },
      user: { id: ADMIN_ID },
    }, mockRes(), jest.fn());
    await flush();

    const dailyActionInserts = client.query.mock.calls
      .filter(([sql]) => String(sql).includes('union_daily_actions'));
    expect(dailyActionInserts).toHaveLength(1);
  });

  // REQ 5a: notification fires on the FIRST publish of the day (todayCount 0).
  it('RULE 5: notification din ki PEHLI publish pe jaata hai', async () => {
    mockPoolBySql({ cnt: 0 });
    createUnionSchedulesBulk({
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: [DRIVER_ID] },
      user: { id: ADMIN_ID },
    }, mockRes(), jest.fn());
    await settle();

    expect(sendPushToMultipleUsers).toHaveBeenCalledTimes(1);
  });

  // REQ 5b: NO notification on the 2nd/3rd publish of the same day (todayCount > 0).
  it('RULE 5: notification doosri/teesri publish pe NAHI jaata', async () => {
    mockPoolBySql({ cnt: 1 });
    createUnionSchedulesBulk({
      body: { from_location: 'Dehradun', to_location: 'Purola', departure_time: new Date().toISOString(), union_driver_ids: [DRIVER_ID] },
      user: { id: ADMIN_ID },
    }, mockRes(), jest.fn());
    await settle();

    expect(sendPushToMultipleUsers).not.toHaveBeenCalled();
  });
});
