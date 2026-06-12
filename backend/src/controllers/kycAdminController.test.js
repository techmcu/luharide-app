/**
 * KYC admin actions — driver/union reverify, pending doc requests
 * SOP: A-001→004 (admin KYC management)
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
const {
  grantDriverReverify, grantUnionReverify, listPendingUnionDocRequests,
} = require('./kycAdminController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const ADMIN_ID = 'a0000000-0000-0000-0000-000000000001';
const USER_ID  = 'b0000000-0000-0000-0000-000000000001';
const UNION_ID = 'c0000000-0000-0000-0000-000000000001';

describe('grantDriverReverify', () => {
  beforeEach(() => jest.clearAllMocks());

  it('grants reverify for valid driver', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{
        id: USER_ID, name: 'Driver', driver_verification_status: 'approved',
        driver_kyc_reupload_granted_on: null,
      }] })
      .mockResolvedValueOnce({ rows: [] })   // UPDATE users
      .mockResolvedValueOnce({ rows: [{ id: 'n1', user_id: USER_ID }] }); // notification

    const req = { params: { userId: USER_ID }, body: {}, user: { id: ADMIN_ID } };
    const res = mockRes();
    grantDriverReverify(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.scope).toBe('driver');
  });

  it('rejects if user not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const req = { params: { userId: USER_ID }, body: {}, user: { id: ADMIN_ID } };
    const next = jest.fn();
    grantDriverReverify(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 404 }));
  });

  it('rejects duplicate reverify on same day', async () => {
    const today = new Date().toISOString().slice(0, 10);
    pool.query.mockResolvedValueOnce({ rows: [{
      id: USER_ID, name: 'Driver', driver_verification_status: 'approved',
      driver_kyc_reupload_granted_on: today,
    }] });

    const req = { params: { userId: USER_ID }, body: {}, user: { id: ADMIN_ID } };
    const next = jest.fn();
    grantDriverReverify(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });
});

describe('grantUnionReverify', () => {
  beforeEach(() => jest.clearAllMocks());

  it('grants reverify for valid union', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{
        id: UNION_ID, name: 'Test Union', documents_reupload_granted_on: null,
      }] })
      .mockResolvedValueOnce({ rows: [] })   // UPDATE unions
      .mockResolvedValueOnce({ rows: [{ id: 'n1', user_id: USER_ID }] }); // notification

    const req = { params: { unionId: UNION_ID }, body: {}, user: { id: ADMIN_ID } };
    const res = mockRes();
    grantUnionReverify(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
  });

  it('rejects if union not found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const req = { params: { unionId: UNION_ID }, body: {}, user: { id: ADMIN_ID } };
    const next = jest.fn();
    grantUnionReverify(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 404 }));
  });
});

describe('listPendingUnionDocRequests', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns pending union doc requests', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ id: UNION_ID, name: 'Test Union', documents_status: 'pending' }],
    });

    const req = { query: { status: 'pending' }, user: { id: ADMIN_ID } };
    const res = mockRes();
    listPendingUnionDocRequests(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.requests).toHaveLength(1);
  });

  it('rejects non-pending status filter', async () => {
    const req = { query: { status: 'approved' }, user: { id: ADMIN_ID } };
    const next = jest.fn();
    listPendingUnionDocRequests(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });
});
