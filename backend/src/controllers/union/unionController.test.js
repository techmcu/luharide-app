/**
 * Union domain tests.
 * Tests registration, admin approve/reject, drivers, routes, schedules.
 * DB mocked — same pattern as bookingController.test.js.
 */

jest.mock('../../config/database', () => ({
  pool: { connect: jest.fn(), query: jest.fn() },
}));
jest.mock('../../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));
jest.mock('../../jobs/kycQueue', () => ({
  enqueueBuildPdf: jest.fn().mockResolvedValue('/uploads/merged.pdf'),
  enqueueCopyPdf: jest.fn().mockResolvedValue('/uploads/copy.pdf'),
}));
jest.mock('../../utils/sanitizeKycUploadUrl', () => ({
  sanitizeKycUploadUrl: jest.fn((url) => url || null),
}));
jest.mock('../../utils/userCache', () => ({
  get: jest.fn(() => null), set: jest.fn(), invalidate: jest.fn(), clear: jest.fn(),
}));

const { pool } = require('../../config/database');
const userCache = require('../../utils/userCache');

const { getMyUnion, registerUnion, updateUnionBranding, updateUnionDocuments } = require('./unionRegistrationController');
const { approveUnionRequest, rejectUnionRequest, listUnions, approveUnion, rejectUnion } = require('./unionAdminController');
const { getUnionDrivers, addUnionDriver, deleteUnionDriver } = require('./unionDriverController');
const { getUnionRoutes, addUnionRoute, deleteUnionRoute } = require('./unionRouteController');
const { createUnionSchedulesBulk, cancelUnionSchedule } = require('./unionScheduleController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}

const flush = () => new Promise(r => setImmediate(r));

// ─────────────────────────────────────────────────────────────────────────────
// GET MY UNION
// ─────────────────────────────────────────────────────────────────────────────

describe('getMyUnion', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns union status none when no union exists', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const res = mockRes();
    const req = { user: { id: 'u-1', role: 'passenger' } };
    getMyUnion(req, res, jest.fn());
    await flush();

    expect(res.status).toHaveBeenCalledWith(200);
    const data = res.json.mock.calls[0][0];
    expect(data.data.status).toBe('none');
    expect(data.data.union).toBeNull();
  });

  it('auto-fixes role when union is approved but user is not union_admin', async () => {
    const union = { id: 'union-1', status: 'approved' };
    pool.query
      .mockResolvedValueOnce({ rows: [union] })  // SELECT union
      .mockResolvedValueOnce({ rows: [] });       // UPDATE role

    const res = mockRes();
    const req = { user: { id: 'u-1', role: 'passenger' } };
    getMyUnion(req, res, jest.fn());
    await flush();

    const roleUpdate = pool.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes("role = 'union_admin'")
    );
    expect(roleUpdate).toBeTruthy();
  });

  it('invalidates the userCache after promoting the role (no stale "Access denied")', async () => {
    const union = { id: 'union-1', status: 'approved' };
    pool.query
      .mockResolvedValueOnce({ rows: [union] }) // SELECT union
      .mockResolvedValueOnce({ rows: [] });      // UPDATE role
    getMyUnion({ user: { id: 'u-1', role: 'passenger' } }, mockRes(), jest.fn());
    await flush();
    expect(userCache.invalidate).toHaveBeenCalledWith('u-1');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// REGISTER UNION
// ─────────────────────────────────────────────────────────────────────────────

describe('registerUnion', () => {
  beforeEach(() => jest.clearAllMocks());

  it('rejects if user already has pending/approved union', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: 'existing', status: 'pending' }] });

    const req = {
      body: { name: 'My Union', location: 'Dehradun', contact_phone: '9876543210', contact_email: 'a@b.com',
              owner_aadhaar_front_url: '/doc1.jpg', owner_aadhaar_back_url: '/doc2.jpg', office_photo_url: '/off.jpg' },
      user: { id: 'u-1' },
    };
    const next = jest.fn();
    registerUnion(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  it('rejects if user has pending driver verification (role exclusivity)', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [] })  // no existing union
      .mockResolvedValueOnce({ rows: [{ driver_verification_status: 'pending' }] }); // driver check

    const req = {
      body: { name: 'My Union', location: 'Dehradun', contact_phone: '9876543210', contact_email: 'a@b.com',
              owner_aadhaar_front_url: '/doc1.jpg', owner_aadhaar_back_url: '/doc2.jpg', office_photo_url: '/off.jpg' },
      user: { id: 'u-1' },
    };
    const next = jest.fn();
    registerUnion(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  it('rejects union name shorter than 3 characters', async () => {
    const req = {
      body: { name: 'AB' },
      user: { id: 'u-1' },
    };
    const next = jest.fn();
    registerUnion(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// APPROVE / REJECT UNION REQUEST
// ─────────────────────────────────────────────────────────────────────────────

describe('approveUnionRequest', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('approves pending union and promotes users to union_admin', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })                              // BEGIN
      .mockResolvedValueOnce({ rows: [{ id: 'union-1', status: 'pending' }] }) // SELECT FOR UPDATE
      .mockResolvedValueOnce({ rows: [] })                              // UPDATE union status
      .mockResolvedValueOnce({ rows: [] })                              // UPDATE users role
      .mockResolvedValueOnce({ rows: [] });                             // COMMIT

    const res = mockRes();
    const req = { params: { id: 'union-1' }, user: { id: 'admin-1' } };
    approveUnionRequest(req, res, jest.fn());
    await flush();

    expect(res.status).toHaveBeenCalledWith(200);
    const rolePromotion = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes("role = 'union_admin'")
    );
    expect(rolePromotion).toBeTruthy();
  });

  it('returns 404 for non-pending union', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })   // BEGIN
      .mockResolvedValueOnce({ rows: [] })   // no pending union found
      .mockResolvedValueOnce({ rows: [] });  // ROLLBACK

    const next = jest.fn();
    const req = { params: { id: 'union-999' }, user: { id: 'admin-1' } };
    approveUnionRequest(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 404 })
    );
  });
});

describe('rejectUnionRequest', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('rejects union and demotes orphaned admins', async () => {
    client.query
      .mockResolvedValueOnce({ rows: [] })                              // BEGIN
      .mockResolvedValueOnce({ rows: [{ id: 'union-1', status: 'pending' }] })
      .mockResolvedValueOnce({ rows: [] })                              // UPDATE union status
      .mockResolvedValueOnce({ rows: [], rowCount: 1 })                 // demoteUnionAdmins
      .mockResolvedValueOnce({ rows: [] })                              // unlinkUnionAdmins
      .mockResolvedValueOnce({ rows: [] });                             // COMMIT

    const res = mockRes();
    const req = { params: { id: 'union-1' }, user: { id: 'admin-1' } };
    rejectUnionRequest(req, res, jest.fn());
    await flush();

    const rejectUpdate = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes("status = 'rejected'")
    );
    expect(rejectUpdate).toBeTruthy();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// PLATFORM ADMIN: listUnions, approveUnion, rejectUnion
// ─────────────────────────────────────────────────────────────────────────────

describe('listUnions (platform admin)', () => {
  beforeEach(() => jest.clearAllMocks());

  it('rejects non-admin user', async () => {
    const next = jest.fn();
    const req = { user: { id: 'u-1', email: 'nobody@x.com' }, query: {} };
    listUnions(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 403 })
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// UNION DRIVERS
// ─────────────────────────────────────────────────────────────────────────────

describe('getUnionDrivers', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns drivers for approved union admin', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: 'union-1' }] })  // union admin check
      .mockResolvedValueOnce({ rows: [
        { id: 'drv-1', name: 'Driver A', vehicle_number: 'UK-01-1234' },
      ] });

    const res = mockRes();
    const req = { user: { id: 'u-1' } };
    getUnionDrivers(req, res, jest.fn());
    await flush();

    expect(res.status).toHaveBeenCalledWith(200);
    const data = res.json.mock.calls[0][0];
    expect(data.data.drivers).toHaveLength(1);
    expect(data.data.count).toBe(1);
  });

  it('rejects if no approved union found', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const next = jest.fn();
    const req = { user: { id: 'u-1' } };
    getUnionDrivers(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 403 })
    );
  });
});

describe('addUnionDriver', () => {
  beforeEach(() => jest.clearAllMocks());

  it('adds driver to union', async () => {
    const driver = { id: 'drv-new', name: 'New Driver', vehicle_number: 'UK-02-5678' };
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: 'union-1' }] })
      .mockResolvedValueOnce({ rows: [driver] });

    const res = mockRes();
    const req = {
      body: { name: 'New Driver', vehicle_number: 'UK-02-5678' },
      user: { id: 'u-1' },
    };
    addUnionDriver(req, res, jest.fn());
    await flush();

    expect(res.status).toHaveBeenCalledWith(201);
  });
});

describe('deleteUnionDriver', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('cancels future schedules and deletes driver', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: 'union-1' }] })           // union admin check
      .mockResolvedValueOnce({ rows: [{ id: 'drv-1', name: 'Driver' }] });  // driver exists

    client.query
      .mockResolvedValueOnce({ rows: [] })   // BEGIN
      .mockResolvedValueOnce({ rows: [] })   // UPDATE schedules cancelled
      .mockResolvedValueOnce({ rows: [] })   // DELETE driver
      .mockResolvedValueOnce({ rows: [] });  // COMMIT

    const res = mockRes();
    const req = { params: { driverId: 'drv-1' }, user: { id: 'u-1' } };
    deleteUnionDriver(req, res, jest.fn());
    await flush();

    expect(res.status).toHaveBeenCalledWith(200);
    const cancelCall = client.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes("status = 'cancelled'")
    );
    expect(cancelCall).toBeTruthy();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// UNION ROUTES
// ─────────────────────────────────────────────────────────────────────────────

describe('addUnionRoute', () => {
  beforeEach(() => jest.clearAllMocks());

  it('creates route for union', async () => {
    const route = { id: 'rt-1', from_location: 'Dehradun', to_location: 'Purola' };
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: 'union-1' }] })
      .mockResolvedValueOnce({ rows: [route] });

    const res = mockRes();
    const req = {
      body: { from_location: 'Dehradun', to_location: 'Purola' },
      user: { id: 'u-1' },
    };
    addUnionRoute(req, res, jest.fn());
    await flush();

    expect(res.status).toHaveBeenCalledWith(201);
  });
});

describe('deleteUnionRoute', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns 404 for route not in union', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: 'union-1' }] })
      .mockResolvedValueOnce({ rows: [], rowCount: 0 });

    const next = jest.fn();
    const req = { params: { routeId: 'rt-999' }, user: { id: 'u-1' } };
    deleteUnionRoute(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 404 })
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// UNION SCHEDULES
// ─────────────────────────────────────────────────────────────────────────────

describe('createUnionSchedulesBulk', () => {
  let client;

  beforeEach(() => {
    jest.clearAllMocks();
    client = { query: jest.fn(), release: jest.fn() };
    pool.connect.mockResolvedValue(client);
  });

  it('rejects empty driver list', async () => {
    const next = jest.fn();
    const req = {
      body: { from_location: 'A', to_location: 'B', departure_time: new Date().toISOString(), union_driver_ids: [] },
      user: { id: 'u-1' },
    };
    createUnionSchedulesBulk(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });

  it('rejects more than 50 drivers', async () => {
    const ids = Array.from({ length: 51 }, (_, i) => `drv-${i}`);
    const next = jest.fn();
    const req = {
      body: { from_location: 'A', to_location: 'B', departure_time: new Date().toISOString(), union_driver_ids: ids },
      user: { id: 'u-1' },
    };
    createUnionSchedulesBulk(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });
});

describe('cancelUnionSchedule', () => {
  beforeEach(() => jest.clearAllMocks());

  it('returns success for already-deleted schedule (idempotent)', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: 'union-1' }] })
      .mockResolvedValueOnce({ rows: [] }); // schedule not found

    const res = mockRes();
    const req = { params: { id: 'sched-999' }, user: { id: 'u-1' } };
    cancelUnionSchedule(req, res, jest.fn());
    await flush();

    expect(res.status).toHaveBeenCalledWith(200);
    const data = res.json.mock.calls[0][0];
    expect(data.data.status).toBe('cancelled');
  });

  it('rejects cancel when outside 1-hour window', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: 'union-1' }] })
      .mockResolvedValueOnce({ rows: [{
        status: 'scheduled',
        departure_time: new Date(Date.now() + 86400000).toISOString(),
        created_at: new Date(Date.now() - 7200000).toISOString(), // 2 hours ago
        can_cancel: false,
      }] });

    const next = jest.fn();
    const req = { params: { id: 'sched-1' }, user: { id: 'u-1' } };
    cancelUnionSchedule(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// UPDATE BRANDING
// ─────────────────────────────────────────────────────────────────────────────

describe('updateUnionBranding', () => {
  beforeEach(() => jest.clearAllMocks());

  it('updates poster settings for approved union', async () => {
    pool.query
      .mockResolvedValueOnce({ rows: [{ union_id: 'union-1' }] })
      .mockResolvedValueOnce({ rows: [] });

    const res = mockRes();
    const req = {
      body: { poster_header: 'My Union Schedule', poster_theme: 'sky' },
      user: { id: 'u-1' },
    };
    updateUnionBranding(req, res, jest.fn());
    await flush();

    expect(res.status).toHaveBeenCalledWith(200);
    const data = res.json.mock.calls[0][0];
    expect(data.data.poster_theme).toBe('sky');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// UPDATE DOCUMENTS
// ─────────────────────────────────────────────────────────────────────────────

describe('updateUnionDocuments', () => {
  beforeEach(() => jest.clearAllMocks());

  it('rejects when docs are approved and no reupload permission', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{
      union_id: 'union-1',
      documents_status: 'approved',
      documents_reupload_allowed: false,
      documents_reupload_deadline: null,
    }] });

    const next = jest.fn();
    const req = {
      body: { owner_name: 'New Name' },
      user: { id: 'u-1' },
    };
    updateUnionDocuments(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 403 })
    );
  });

  it('rejects when no fields to update', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{
      union_id: 'union-1',
      documents_status: 'pending',
      documents_reupload_allowed: false,
      documents_reupload_deadline: null,
    }] });

    const next = jest.fn();
    const req = {
      body: {},
      user: { id: 'u-1' },
    };
    updateUnionDocuments(req, mockRes(), next);
    await flush();

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 400 })
    );
  });
});
