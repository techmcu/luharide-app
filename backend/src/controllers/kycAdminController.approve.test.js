/**
 * Admin approve/reject union doc requests — SOP A-008→010
 * DB and socket are mocked — no real database connection.
 */

jest.mock('../config/database', () => ({
  pool: { query: jest.fn() },
}));
jest.mock('../socket/realtimeEmitter', () => ({
  emitNotificationToUser: jest.fn(),
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { pool } = require('../config/database');
const { approveUnionDocRequest, rejectUnionDocRequest } = require('./kycAdminController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const UNION_ID = 'c0000000-0000-0000-0000-000000000001';
const ADMIN_ID = 'a0000000-0000-0000-0000-000000000001';

describe('approveUnionDocRequest', () => {
  beforeEach(() => jest.clearAllMocks());

  it('approves pending union documents', async () => {
    pool.query
      .mockResolvedValueOnce({ rowCount: 1, rows: [{ id: UNION_ID }] })  // UPDATE unions
      .mockResolvedValueOnce({ rows: [{ id: 'n1', user_id: 'u1' }] });  // notification

    const req = { params: { id: UNION_ID }, user: { id: ADMIN_ID } };
    const res = mockRes();
    approveUnionDocRequest(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.status).toBe('approved');
  });

  it('rejects when no pending request found', async () => {
    pool.query.mockResolvedValueOnce({ rowCount: 0, rows: [] });

    const req = { params: { id: UNION_ID }, user: { id: ADMIN_ID } };
    const next = jest.fn();
    approveUnionDocRequest(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 404 }));
  });
});

describe('rejectUnionDocRequest', () => {
  beforeEach(() => jest.clearAllMocks());

  it('rejects union docs and reopens reupload', async () => {
    pool.query
      .mockResolvedValueOnce({ rowCount: 1, rows: [{ id: UNION_ID }] })  // UPDATE unions
      .mockResolvedValueOnce({ rows: [{ id: 'n1', user_id: 'u1' }] });  // notification

    const req = { params: { id: UNION_ID }, body: { reason: 'Blurry photo' }, user: { id: ADMIN_ID } };
    const res = mockRes();
    rejectUnionDocRequest(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.status).toBe('needs_reverify');
  });

  it('returns 404 when no pending request', async () => {
    pool.query.mockResolvedValueOnce({ rowCount: 0, rows: [] });

    const req = { params: { id: UNION_ID }, body: {}, user: { id: ADMIN_ID } };
    const next = jest.fn();
    rejectUnionDocRequest(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 404 }));
  });
});
