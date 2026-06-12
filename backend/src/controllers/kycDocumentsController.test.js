/**
 * KYC submitted documents retrieval — SOP D-035→036
 * DB is mocked — no real database connection.
 */

jest.mock('../config/database', () => ({
  pool: { query: jest.fn() },
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { pool } = require('../config/database');
const { getMySubmittedDocuments } = require('./kycDocumentsController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const USER_ID = 'b0000000-0000-0000-0000-000000000001';

describe('getMySubmittedDocuments', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns documents for driver with verified uploads', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{
        user_id: USER_ID,
        aadhaar_front_url: '/uploads/kyc/aadhaar-front.pdf',
        aadhaar_back_url: '/uploads/kyc/aadhaar-back.pdf',
        driving_license_front_url: '/uploads/kyc/dl-front.pdf',
        updated_at: new Date(),
      }] })
      .mockResolvedValueOnce({ rows: [] }); // no union

    const req = { user: { id: USER_ID } };
    const res = mockRes();
    getMySubmittedDocuments(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.disclaimer).toBeTruthy();
    expect(Array.isArray(body.data.documents)).toBe(true);
  });

  it('returns empty documents for user with no verification', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [] })  // no driver verification
      .mockResolvedValueOnce({ rows: [] }); // no union

    const req = { user: { id: USER_ID } };
    const res = mockRes();
    getMySubmittedDocuments(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.documents).toHaveLength(0);
  });
});
