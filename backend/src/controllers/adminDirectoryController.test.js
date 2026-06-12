/**
 * Admin directory — driver/union lists — SOP A-005→007
 * DB is mocked — no real database connection.
 */

jest.mock('../config/database', () => ({
  queryRead: jest.fn(),
}));

const { queryRead } = require('../config/database');
const { listIndependentDriversDirectory, listUnionsDirectory } = require('./adminDirectoryController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const ADMIN_ID = 'a0000000-0000-0000-0000-000000000001';

describe('listIndependentDriversDirectory', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns paginated driver list', async () => {
    queryRead
      .mockResolvedValueOnce({ rows: [{ n: 5 }] })   // COUNT
      .mockResolvedValueOnce({ rows: [
        { id: 'd1', name: 'Driver A', role: 'driver', driver_verification_status: 'approved' },
        { id: 'd2', name: 'Driver B', role: 'driver', driver_verification_status: 'pending' },
      ] });

    const req = { query: { limit: '10', offset: '0' }, user: { id: ADMIN_ID } };
    const res = mockRes();
    listIndependentDriversDirectory(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.total).toBe(5);
    expect(body.data.drivers).toHaveLength(2);
  });

  it('clamps limit to max 500', async () => {
    queryRead
      .mockResolvedValueOnce({ rows: [{ n: 0 }] })
      .mockResolvedValueOnce({ rows: [] });

    const req = { query: { limit: '9999', offset: '0' }, user: { id: ADMIN_ID } };
    const res = mockRes();
    listIndependentDriversDirectory(req, res, jest.fn());
    await flush();

    const call = queryRead.mock.calls[1];
    expect(call[1][0]).toBe(500); // clamped limit
  });

  it('defaults limit when not provided', async () => {
    queryRead
      .mockResolvedValueOnce({ rows: [{ n: 0 }] })
      .mockResolvedValueOnce({ rows: [] });

    const req = { query: {}, user: { id: ADMIN_ID } };
    const res = mockRes();
    listIndependentDriversDirectory(req, res, jest.fn());
    await flush();

    const call = queryRead.mock.calls[1];
    expect(call[1][0]).toBe(100); // default
  });
});

describe('listUnionsDirectory', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns paginated union list', async () => {
    queryRead
      .mockResolvedValueOnce({ rows: [{ n: 3 }] })
      .mockResolvedValueOnce({ rows: [
        { id: 'u1', name: 'Union A', status: 'approved' },
      ] });

    const req = { query: { limit: '10', offset: '0' }, user: { id: ADMIN_ID } };
    const res = mockRes();
    listUnionsDirectory(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.total).toBe(3);
    expect(body.data.unions).toHaveLength(1);
  });
});
