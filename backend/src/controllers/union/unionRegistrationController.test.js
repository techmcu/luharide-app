/**
 * Union registration + schedule creation — SOP U-001→005
 * DB and queue are mocked — no real database connection.
 */

jest.mock('../../config/database', () => ({
  pool: { query: jest.fn(), connect: jest.fn() },
}));
jest.mock('../../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));
jest.mock('../../jobs/kycQueue', () => ({
  enqueueBuildPdf: jest.fn().mockResolvedValue('/uploads/union-doc.pdf'),
  enqueueCopyPdf: jest.fn().mockResolvedValue('/uploads/union-copy.pdf'),
}));
jest.mock('../../utils/sanitizeKycUploadUrl', () => ({
  sanitizeKycUploadUrl: jest.fn(url => url),
}));
jest.mock('./unionHelpers', () => ({
  demoteUnionAdminsOrphanedByReject: jest.fn().mockResolvedValue(),
  unlinkUnionAdminsForRejectedUnion: jest.fn().mockResolvedValue(),
  cleanPosterHeader: jest.fn(v => v),
  cleanPosterCustomText: jest.fn(v => v),
  getPosterTheme: jest.fn(() => 'default'),
}));

const { pool } = require('../../config/database');
const { getMyUnion, registerUnion } = require('./unionRegistrationController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const USER_ID  = 'b0000000-0000-0000-0000-000000000001';
const UNION_ID = 'c0000000-0000-0000-0000-000000000001';

describe('getMyUnion', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns union for user with approved union', async () => {
    pool.query.mockResolvedValueOnce({
      rows: [{ id: UNION_ID, name: 'Test Union', status: 'approved' }],
    });

    const req = { user: { id: USER_ID, role: 'union_admin' } };
    const res = mockRes();
    getMyUnion(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.status).toBe('approved');
  });

  it('returns none status when no union exists', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const req = { user: { id: USER_ID, role: 'passenger' } };
    const res = mockRes();
    getMyUnion(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.status).toBe('none');
  });

  it('cleans up rejected union and returns none', async () => {
    const { demoteUnionAdminsOrphanedByReject, unlinkUnionAdminsForRejectedUnion } = require('./unionHelpers');

    pool.query.mockResolvedValueOnce({
      rows: [{ id: UNION_ID, name: 'Rejected Union', status: 'rejected' }],
    });

    const req = { user: { id: USER_ID, role: 'passenger' } };
    const res = mockRes();
    getMyUnion(req, res, jest.fn());
    await flush();

    expect(demoteUnionAdminsOrphanedByReject).toHaveBeenCalledWith(UNION_ID);
    expect(unlinkUnionAdminsForRejectedUnion).toHaveBeenCalledWith(UNION_ID);
    const body = res.json.mock.calls[0][0];
    expect(body.data.status).toBe('none');
  });
});

describe('registerUnion', () => {
  beforeEach(() => jest.clearAllMocks());

  it('rejects name shorter than 3 characters', async () => {
    const req = {
      body: { name: 'AB', contact_phone: '9876543210', location: 'Dehradun' },
      user: { id: USER_ID },
    };
    const next = jest.fn();
    registerUnion(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects phone shorter than 10 digits', async () => {
    const req = {
      body: { name: 'Test Union', contact_phone: '12345', location: 'Dehradun' },
      user: { id: USER_ID },
    };
    const next = jest.fn();
    registerUnion(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });

  it('rejects if user already has active union', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ id: UNION_ID, status: 'approved' }] }); // existing active

    const req = {
      body: { name: 'Test Union', contact_phone: '9876543210', location: 'Dehradun' },
      user: { id: USER_ID },
    };
    const next = jest.fn();
    registerUnion(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 400 }));
  });
});
