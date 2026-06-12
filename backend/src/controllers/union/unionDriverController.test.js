/**
 * Union driver CRUD — SOP U-006→009
 * DB is mocked — no real database connection.
 */

jest.mock('../../config/database', () => ({
  pool: { query: jest.fn(), connect: jest.fn() },
}));
jest.mock('../../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { pool } = require('../../config/database');
const { getUnionDrivers, addUnionDriver, deleteUnionDriver } = require('./unionDriverController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const ADMIN_ID  = 'a0000000-0000-0000-0000-000000000001';
const UNION_ID  = 'c0000000-0000-0000-0000-000000000001';
const DRIVER_ID = 'd0000000-0000-0000-0000-000000000001';

describe('getUnionDrivers', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns drivers for approved union', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: UNION_ID }] })
      .mockResolvedValueOnce({ rows: [
        { id: DRIVER_ID, name: 'Driver 1', vehicle_number: 'UK07-1234' },
      ] });

    const req = { user: { id: ADMIN_ID } };
    const res = mockRes();
    getUnionDrivers(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.drivers).toHaveLength(1);
    expect(body.data.count).toBe(1);
  });

  it('rejects when no approved union found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const req = { user: { id: ADMIN_ID } };
    const next = jest.fn();
    getUnionDrivers(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
  });
});

describe('addUnionDriver', () => {
  beforeEach(() => jest.clearAllMocks());

  it('adds driver to union', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: UNION_ID }] })
      .mockResolvedValueOnce({ rows: [{
        id: DRIVER_ID, union_id: UNION_ID, name: 'New Driver', vehicle_number: 'UK07-5678',
      }] });

    const req = {
      body: { name: 'New Driver', vehicle_number: 'UK07-5678', phone: '9876543210' },
      user: { id: ADMIN_ID },
    };
    const res = mockRes();
    addUnionDriver(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.driver.name).toBe('New Driver');
  });

  it('rejects when no approved union', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const req = {
      body: { name: 'New Driver', vehicle_number: 'UK07-5678' },
      user: { id: ADMIN_ID },
    };
    const next = jest.fn();
    addUnionDriver(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
  });
});

describe('deleteUnionDriver', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('deletes driver and cancels future schedules', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: UNION_ID }] })
      .mockResolvedValueOnce({ rows: [{ id: DRIVER_ID, name: 'Driver' }] });

    client.query
      .mockResolvedValueOnce({ rows: [] })  // BEGIN
      .mockResolvedValueOnce({ rows: [] })  // UPDATE union_schedules cancelled
      .mockResolvedValueOnce({ rows: [] })  // DELETE union_drivers
      .mockResolvedValueOnce({ rows: [] }); // COMMIT

    const req = { params: { driverId: DRIVER_ID }, user: { id: ADMIN_ID } };
    const res = mockRes();
    deleteUnionDriver(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const cancelCall = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes("status = 'cancelled'")
    );
    expect(cancelCall).toBeTruthy();
  });

  it('rejects when driver not found in union', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: UNION_ID }] })
      .mockResolvedValueOnce({ rows: [] }); // driver not found

    const req = { params: { driverId: DRIVER_ID }, user: { id: ADMIN_ID } };
    const next = jest.fn();
    deleteUnionDriver(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 404 }));
  });

  it('rejects when no approved union', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const req = { params: { driverId: DRIVER_ID }, user: { id: ADMIN_ID } };
    const next = jest.fn();
    deleteUnionDriver(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(expect.objectContaining({ statusCode: 403 }));
  });
});
