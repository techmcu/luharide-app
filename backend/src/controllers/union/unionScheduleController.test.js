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

const { pool } = require('../../config/database');
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
});
