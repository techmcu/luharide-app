/**
 * Union schedule creation (createUnionSchedulesBulk) + pure validation helpers.
 * DB and external services are mocked — no real database, no network.
 *
 * ┌─────────────────────────────────────────────────────────────────────────┐
 * │ 🔒 RULE LOCKS — READ THIS IF CI FAILS HERE                                │
 * │                                                                           │
 * │ Agar GitHub CI laal (red) ho aur niche koi "RULE N: ..." test fail dikhe, │
 * │ matlab tumne us STABLE rule ko galti se tod diya. Test ka NAAM batata hai  │
 * │ kya toota. Niche map se code ki jagah dekho aur wahi theek karo:           │
 * │                                                                           │
 * │  RULE 1  Ek publish mein kam se kam 1 ride            → validateScheduleItems
 * │  RULE 2  Ek publish mein zyada se zyada 50 ride       → validateScheduleItems
 * │  RULE 3  Din mein sirf 3 baar publish (race-safe)     → createUnionSchedulesBulk txn
 * │  RULE 4  Ek publish = sirf 1 ginti (1..50 ride)       → one daily-action INSERT
 * │  RULE 5  Notification sirf din ki PEHLI publish pe     → if (todayCount === 0)
 * │  RULE 6  Ride sirf FUTURE ki, past ki nahi            → isFutureDeparture
 * │  RULE 7  Har ride ka apna route+time ho sakta hai     → normalizeScheduleItems(schedules[])
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
jest.mock('../../utils/titleCase', () => jest.fn((s) => s));
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
const {
  createUnionSchedulesBulk,
  normalizeScheduleItems,
  departureToInstantISO,
  isFutureDeparture,
  validateScheduleItems,
} = require('./unionScheduleController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise((r) => setImmediate(r));
const settle = async () => { for (let i = 0; i < 6; i++) await flush(); };

const ADMIN_ID  = 'a0000000-0000-0000-0000-000000000001';
const UNION_ID  = 'c0000000-0000-0000-0000-000000000001';
const DRIVER_ID = 'd0000000-0000-0000-0000-000000000001';
const futureTime = () => new Date(Date.now() + 60 * 60 * 1000).toISOString();
const pastTime   = () => new Date(Date.now() - 60 * 60 * 1000).toISOString();

// ════════════════════════════════════════════════════════════════════════════
//  PURE HELPERS — no DB, fast, every edge case
// ════════════════════════════════════════════════════════════════════════════

describe('normalizeScheduleItems', () => {
  test('RULE 7: NEW schedules[] shape — each ride keeps its own route + time', () => {
    const items = normalizeScheduleItems({
      schedules: [
        { union_driver_id: 'd1', from_location: 'Dehradun', to_location: 'Purola', departure_time: '2030-01-01T05:00:00.000Z', from_lat: '30.3', from_lng: 78.0 },
        { union_driver_id: 'd2', from_location: 'Purola', to_location: 'Dehradun', departure_time: '2030-01-01T06:00:00.000Z' },
      ],
    });
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ unionDriverId: 'd1', fromLocation: 'Dehradun', toLocation: 'Purola', departureTime: '2030-01-01T05:00:00.000Z', fromLat: 30.3, fromLng: 78.0 });
    expect(items[1]).toMatchObject({ unionDriverId: 'd2', fromLocation: 'Purola', toLocation: 'Dehradun', departureTime: '2030-01-01T06:00:00.000Z' });
  });

  test('LEGACY union_driver_ids shape — one shared route+time fans out per driver', () => {
    const items = normalizeScheduleItems({
      union_driver_ids: ['d1', 'd2', 'd3'],
      from_location: 'Dehradun', to_location: 'Purola', departure_time: '2030-01-01T05:00:00.000Z',
    });
    expect(items).toHaveLength(3);
    expect(items.every((it) => it.fromLocation === 'Dehradun' && it.toLocation === 'Purola' && it.departureTime === '2030-01-01T05:00:00.000Z')).toBe(true);
  });

  test('empty / missing body → empty list (caller rejects)', () => {
    expect(normalizeScheduleItems({})).toEqual([]);
    expect(normalizeScheduleItems(undefined)).toEqual([]);
    expect(normalizeScheduleItems({ union_driver_ids: [] })).toEqual([]);
  });

  test('coerces numeric-string coords, trims text, tolerates junk coords', () => {
    const [it] = normalizeScheduleItems({
      schedules: [{ union_driver_id: '  d1  ', from_location: ' A ', to_location: ' B ', from_lat: 'abc', to_lng: '' }],
    });
    expect(it.unionDriverId).toBe('d1');
    expect(it.fromLocation).toBe('A');
    expect(it.fromLat).toBeNull(); // 'abc' → null, never NaN
    expect(it.toLng).toBeNull();
  });
});

describe('departureToInstantISO (THE TIME BUG fix)', () => {
  test('naked local datetime is read as IST wall-clock (+05:30 attached)', () => {
    // 10:00 IST == 04:30 UTC — the union picks 10:00, the world stores 04:30Z.
    expect(departureToInstantISO('2030-06-27T10:00:00.000')).toBe('2030-06-27T04:30:00.000Z');
    expect(departureToInstantISO('2030-06-27T10:00:00')).toBe('2030-06-27T04:30:00.000Z');
  });
  test('explicit Z instant is respected as-is', () => {
    expect(departureToInstantISO('2030-06-27T04:30:00.000Z')).toBe('2030-06-27T04:30:00.000Z');
  });
  test('explicit +05:30 offset is respected (same instant as naked IST)', () => {
    expect(departureToInstantISO('2030-06-27T10:00:00+05:30')).toBe('2030-06-27T04:30:00.000Z');
  });
  test('null / empty / unparseable → null', () => {
    expect(departureToInstantISO(null)).toBeNull();
    expect(departureToInstantISO(undefined)).toBeNull();
    expect(departureToInstantISO('')).toBeNull();
    expect(departureToInstantISO('   ')).toBeNull();
    expect(departureToInstantISO('not-a-date')).toBeNull();
  });
});

describe('isFutureDeparture', () => {
  const now = Date.now();
  test('future time → true', () => expect(isFutureDeparture(new Date(now + 3600_000).toISOString(), now)).toBe(true));
  test('clearly past time → false', () => expect(isFutureDeparture(new Date(now - 3600_000).toISOString(), now)).toBe(false));
  test('within 1-min skew grace → true', () => expect(isFutureDeparture(new Date(now - 30_000).toISOString(), now)).toBe(true));
  test('null / empty → false', () => { expect(isFutureDeparture(null, now)).toBe(false); expect(isFutureDeparture('', now)).toBe(false); });
  test('unparseable → false', () => expect(isFutureDeparture('not-a-date', now)).toBe(false));
});

describe('validateScheduleItems', () => {
  const ok = (over = {}) => ({ unionDriverId: 'd1', fromLocation: 'A', toLocation: 'B', departureTime: futureTime(), ...over });

  test('RULE 1: empty batch → 400', () => {
    expect(() => validateScheduleItems([])).toThrow(expect.objectContaining({ statusCode: 400 }));
  });
  test('RULE 2: more than 50 rides → 400', () => {
    const big = Array.from({ length: 51 }, (_, i) => ok({ unionDriverId: `d${i}` }));
    expect(() => validateScheduleItems(big)).toThrow(expect.objectContaining({ statusCode: 400 }));
  });
  test('exactly 50 rides is allowed', () => {
    const fifty = Array.from({ length: 50 }, (_, i) => ok({ unionDriverId: `d${i}` }));
    expect(() => validateScheduleItems(fifty)).not.toThrow();
  });
  test('missing driver → 400', () => {
    expect(() => validateScheduleItems([ok({ unionDriverId: '' })])).toThrow(expect.objectContaining({ statusCode: 400 }));
  });
  test('missing from/to → 400', () => {
    expect(() => validateScheduleItems([ok({ toLocation: '' })])).toThrow(expect.objectContaining({ statusCode: 400 }));
  });
  test('RULE 6: a past departure time → 400', () => {
    expect(() => validateScheduleItems([ok({ departureTime: pastTime() })])).toThrow(expect.objectContaining({ statusCode: 400 }));
  });
  test('returns DISTINCT driver ids (dedupes)', () => {
    const ids = validateScheduleItems([ok({ unionDriverId: 'd1' }), ok({ unionDriverId: 'd1' }), ok({ unionDriverId: 'd2' })]);
    expect(ids.sort()).toEqual(['d1', 'd2']);
  });
});

// ════════════════════════════════════════════════════════════════════════════
//  CONTROLLER — DB mocked by SQL content (order-independent)
// ════════════════════════════════════════════════════════════════════════════

describe('createUnionSchedulesBulk', () => {
  let client;

  // Routes pool.query (main + background + FCM) and client.query (txn) by SQL text.
  function mockDb({ cnt = 0, fcmEnabled = false, validDrivers = [DRIVER_ID], created } = {}) {
    pool.query.mockImplementation((sql) => {
      const s = String(sql);
      if (s.includes('FROM union_admins')) {
        return Promise.resolve({ rows: [{ union_id: UNION_ID, union_name: 'Test', fcm_enabled: fcmEnabled }] });
      }
      if (s.includes('FROM union_drivers')) {
        return Promise.resolve({ rows: validDrivers.map((id) => ({ id })) });
      }
      if (s.includes('fcm_global_union_rides')) return Promise.resolve({ rows: [{ value: 'true' }] });
      if (s.includes("role = 'passenger'")) return Promise.resolve({ rows: [{ id: 'p1' }] });
      return Promise.resolve({ rows: [] }); // background geo UPDATEs
    });
    client = { query: jest.fn(), release: jest.fn() };
    client.query.mockImplementation((sql) => {
      const s = String(sql);
      if (s.includes('union_daily_actions') && s.includes('COUNT')) return Promise.resolve({ rows: [{ cnt }] });
      if (s.includes('INSERT INTO union_schedules')) {
        return Promise.resolve({ rows: created || [{ id: 's-1', union_driver_id: DRIVER_ID }] });
      }
      return Promise.resolve({ rows: [] }); // BEGIN, FOR UPDATE, daily-action INSERT, COMMIT, ROLLBACK
    });
    pool.connect.mockResolvedValue(client);
  }

  const call = (body) => {
    const res = mockRes();
    const next = jest.fn();
    createUnionSchedulesBulk({ body, user: { id: ADMIN_ID } }, res, next);
    return { res, next };
  };

  beforeEach(() => jest.clearAllMocks());

  test('RULE 1: empty driver batch → 400', async () => {
    mockDb();
    const { next } = call({ union_driver_ids: [] });
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  test('RULE 2: more than 50 rides → 400', async () => {
    mockDb();
    const big = Array.from({ length: 51 }, (_, i) => ({ union_driver_id: `d${i}`, from_location: 'A', to_location: 'B', departure_time: futureTime() }));
    const { next } = call({ schedules: big });
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  test('RULE 6: a past departure time → 400 (no DB write)', async () => {
    mockDb();
    const { next } = call({ schedules: [{ union_driver_id: DRIVER_ID, from_location: 'A', to_location: 'B', departure_time: pastTime() }] });
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
    expect(pool.connect).not.toHaveBeenCalled();
  });

  test('no approved union for admin → 403', async () => {
    mockDb({ validDrivers: [DRIVER_ID] });
    pool.query.mockImplementationOnce(() => Promise.resolve({ rows: [] })); // union lookup empty
    const { next } = call({ union_driver_ids: [DRIVER_ID], from_location: 'A', to_location: 'B', departure_time: futureTime() });
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
  });

  test('a driver not belonging to the union → 400', async () => {
    mockDb({ validDrivers: [] }); // ownership check returns nothing
    const { next } = call({ union_driver_ids: [DRIVER_ID], from_location: 'A', to_location: 'B', departure_time: futureTime() });
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  test('RULE 3: 4th publish of the day → 400 (limit checked inside the txn)', async () => {
    mockDb({ cnt: 3 });
    const { next } = call({ union_driver_ids: [DRIVER_ID], from_location: 'A', to_location: 'B', departure_time: futureTime() });
    await flush();
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
    // must roll the transaction back, never commit
    const sqls = client.query.mock.calls.map(([s]) => String(s));
    expect(sqls).toEqual(expect.arrayContaining([expect.stringContaining('ROLLBACK')]));
    expect(sqls).not.toEqual(expect.arrayContaining([expect.stringContaining('COMMIT')]));
  });

  test('RULE 7: many drivers with DIFFERENT routes in ONE publish → 201, all created', async () => {
    const drivers = ['d1', 'd2', 'd3'];
    const created = drivers.map((d, i) => ({ id: `s-${i}`, union_driver_id: d }));
    mockDb({ cnt: 0, validDrivers: drivers, created });
    const { res, next } = call({
      schedules: [
        { union_driver_id: 'd1', from_location: 'Dehradun', to_location: 'Purola', departure_time: futureTime() },
        { union_driver_id: 'd2', from_location: 'Purola', to_location: 'Dehradun', departure_time: futureTime() },
        { union_driver_id: 'd3', from_location: 'Naugaon', to_location: 'Roorkee', departure_time: futureTime() },
      ],
    });
    await flush();
    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json.mock.calls[0][0].data.count).toBe(3);
  });

  test('RULE 4: one publish records EXACTLY ONE daily-action, even with many rides', async () => {
    const drivers = Array.from({ length: 10 }, (_, i) => `d${i}`);
    const created = drivers.map((d, i) => ({ id: `s-${i}`, union_driver_id: d }));
    mockDb({ cnt: 0, validDrivers: drivers, created });
    call({ schedules: drivers.map((d) => ({ union_driver_id: d, from_location: 'A', to_location: 'B', departure_time: futureTime() })) });
    await flush();
    const dailyInserts = client.query.mock.calls.filter(([s]) => String(s).includes('INSERT INTO union_daily_actions'));
    expect(dailyInserts).toHaveLength(1);
  });

  test('RULE 5: notification fires on the FIRST publish of the day', async () => {
    mockDb({ cnt: 0, fcmEnabled: true });
    call({ union_driver_ids: [DRIVER_ID], from_location: 'A', to_location: 'B', departure_time: futureTime() });
    await settle();
    expect(sendPushToMultipleUsers).toHaveBeenCalledTimes(1);
  });

  test('RULE 5: notification does NOT fire on later publishes of the same day', async () => {
    mockDb({ cnt: 1, fcmEnabled: true });
    call({ union_driver_ids: [DRIVER_ID], from_location: 'A', to_location: 'B', departure_time: futureTime() });
    await settle();
    expect(sendPushToMultipleUsers).not.toHaveBeenCalled();
  });

  test('REGRESSION: a failing Ola Maps lookup never blocks/breaks creation (still 201)', async () => {
    mockDb({ cnt: 1 });
    olaMaps.getRouteDistance.mockRejectedValueOnce(new Error('ola maps down'));
    olaMaps.geocode.mockRejectedValueOnce(new Error('ola maps down'));
    const { res, next } = call({ union_driver_ids: [DRIVER_ID], from_location: 'A', to_location: 'B', departure_time: futureTime() });
    await settle();
    expect(next).not.toHaveBeenCalled();
    expect(res.status).toHaveBeenCalledWith(201);
  });
});
