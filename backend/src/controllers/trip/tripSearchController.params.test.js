/**
 * Regression lock for the proximity ("rides near you") SQL.
 *
 * THE BUG this guards: the corridor (along-route) queries used to pass 11 bind
 * params but reference only $5..$11 — the 4 unused params made Postgres throw
 * "could not determine data type of parameter $1", so corridor matching silently
 * failed on EVERY coordinate search (a ride passing through your stop wouldn't show).
 *
 * The invariant below — every bind param passed is referenced, and nothing beyond
 * the supplied count is referenced — would have caught it, and now blocks the whole
 * CLASS of bug for every query proximitySearch builds (endpoint + corridor + text,
 * trips + union). No real database: queryRead is mocked to capture (text, values).
 */

jest.mock('../../config/database', () => ({
  pool: {},
  queryRead: jest.fn(),
}));
jest.mock('../../config/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }));
jest.mock('./seatLockController', () => ({ getLockedSeatNumbers: jest.fn().mockResolvedValue([]) }));
jest.mock('../../services/olaMapsService', () => ({
  isValidLatLng: jest.fn(() => true),
  haversineKm: jest.fn(() => 50),
  projectOntoPolyline: jest.fn(() => ({ distKm: 1, alongKm: 1 })),
}));

const { queryRead } = require('../../config/database');
const { searchTrips } = require('./tripSearchController');

/** Assert every $N passed is referenced, and no $N beyond the supplied count is used. */
function assertParamsConsistent(text, values, label) {
  const used = new Set();
  const re = /\$(\d+)/g;
  let m;
  while ((m = re.exec(text)) !== null) used.add(Number(m[1]));
  const maxUsed = used.size ? Math.max(...used) : 0;
  // (a) no placeholder may reference past the values actually supplied
  expect(`${label}: maxUsed=${maxUsed} supplied=${values.length}`)
    .toBe(`${label}: maxUsed=${Math.min(maxUsed, values.length)} supplied=${values.length}`);
  // (b) every supplied value must be referenced (no dead params → no "could not determine type")
  for (let i = 1; i <= values.length; i++) {
    expect(`${label} references $${i}: ${used.has(i)}`).toBe(`${label} references $${i}: true`);
  }
}

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}

// Let all in-flight queries (trips + union run in parallel) settle before asserting.
const settle = async () => { for (let i = 0; i < 8; i++) await new Promise((r) => setImmediate(r)); };

describe('proximitySearch — bind-param consistency (no dead params)', () => {
  it('every SQL built passes exactly the params it references (endpoint + corridor + text, trips + union)', async () => {
    const captured = [];
    queryRead.mockImplementation((text, values) => {
      captured.push([String(text), values]);
      return Promise.resolve({ rows: [] });
    });

    const req = {
      query: {
        from: 'Dehradun', to: 'Uttarkashi',
        from_lat: '30.3165', from_lng: '78.0322',
        to_lat: '30.7268', to_lng: '78.4354',
        date: '2026-06-27',
      },
      body: {},
    };
    await searchTrips(req, mockRes(), jest.fn());
    await settle(); // trips + union queries run in parallel; wait for all to fire

    // The corridor queries are the ones that regressed — make sure they actually ran.
    const sqls = captured.map(([t]) => t);
    expect(sqls.some((s) => s.includes('route_polyline IS NOT NULL') && s.includes('FROM trips'))).toBe(true);
    expect(sqls.some((s) => s.includes('route_polyline IS NOT NULL') && s.includes('union_schedules'))).toBe(true);

    expect(captured.length).toBeGreaterThanOrEqual(4);
    captured.forEach(([text, values], i) => {
      expect(Array.isArray(values)).toBe(true);
      assertParamsConsistent(text, values, `query #${i}`);
    });
  });
});
