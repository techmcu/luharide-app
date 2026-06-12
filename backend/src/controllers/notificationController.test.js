/**
 * Notification controller tests — SOP P-054→057
 * DB is mocked — no real database connection is ever made.
 */

jest.mock('../config/database', () => ({
  pool: { query: jest.fn() },
  queryRead: jest.fn(),
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));

const { pool, queryRead } = require('../config/database');
const { getMyNotifications, markAsRead, markAllAsRead } = require('./notificationController');

function mockRes() {
  return { status: jest.fn().mockReturnThis(), json: jest.fn().mockReturnThis() };
}
const flush = () => new Promise(r => setImmediate(r));

const USER_ID = 'c0000000-0000-0000-0000-000000000001';

describe('getMyNotifications', () => {
  beforeEach(() => jest.clearAllMocks());

  // ── SOP P-054: View notifications list ────────────────────────────────────
  it('returns notifications for user', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] }); // DELETE old
    queryRead.mockResolvedValueOnce({
      rows: [
        { id: 'n1', type: 'booking_confirmed', title: 'Booking confirmed', message: 'Seat booked', is_read: false, created_at: new Date() },
        { id: 'n2', type: 'rate_ride', title: 'Rate', message: 'Rate your ride', is_read: true, created_at: new Date() },
      ],
    });

    const req = { user: { id: USER_ID } };
    const res = mockRes();
    getMyNotifications(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.notifications).toHaveLength(2);
  });

  // ── Retention cleanup runs before fetch ───────────────────────────────────
  it('deletes old notifications before fetching', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    queryRead.mockResolvedValueOnce({ rows: [] });

    const req = { user: { id: USER_ID } };
    getMyNotifications(req, mockRes(), jest.fn());
    await flush();

    const deleteCall = pool.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('DELETE FROM notifications')
    );
    expect(deleteCall).toBeTruthy();
  });

  // ── SOP P-057: Unread count derivable from list ───────────────────────────
  it('returns both read and unread notifications', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });
    queryRead.mockResolvedValueOnce({
      rows: [
        { id: 'n1', is_read: false },
        { id: 'n2', is_read: false },
        { id: 'n3', is_read: true },
      ],
    });

    const req = { user: { id: USER_ID } };
    const res = mockRes();
    getMyNotifications(req, res, jest.fn());
    await flush();

    const body = res.json.mock.calls[0][0];
    const unread = body.data.notifications.filter(n => !n.is_read);
    expect(unread).toHaveLength(2);
  });
});

describe('markAsRead', () => {
  beforeEach(() => jest.clearAllMocks());

  // ── SOP P-055: Mark single notification read ──────────────────────────────
  it('marks notification as read', async () => {
    pool.query.mockResolvedValueOnce({ rows: [{ id: 'n1' }] });

    const req = { params: { id: 'n1' }, user: { id: USER_ID } };
    const res = mockRes();
    markAsRead(req, res, jest.fn());
    await flush();

    expect(pool.query).toHaveBeenCalledWith(
      expect.stringContaining('SET is_read = TRUE'),
      ['n1', USER_ID]
    );
    expect(res.json).toHaveBeenCalled();
  });

  // ── Non-existent notification ─────────────────────────────────────────────
  it('handles non-existent notification gracefully', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const req = { params: { id: 'n999' }, user: { id: USER_ID } };
    const res = mockRes();
    markAsRead(req, res, jest.fn());
    await flush();

    expect(res.json).toHaveBeenCalled();
    const body = res.json.mock.calls[0][0];
    expect(body.data.message).toContain('removed');
  });

  // ── Wrong user's notification ─────────────────────────────────────────────
  it('does not mark another users notification (WHERE user_id)', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] }); // no match for wrong user_id

    const req = { params: { id: 'n1' }, user: { id: 'x0000000-0000-0000-0000-000000000099' } };
    const res = mockRes();
    markAsRead(req, res, jest.fn());
    await flush();

    expect(pool.query).toHaveBeenCalledWith(
      expect.stringContaining('user_id = $2'),
      ['n1', 'x0000000-0000-0000-0000-000000000099']
    );
  });
});

describe('markAllAsRead', () => {
  beforeEach(() => jest.clearAllMocks());

  // ── SOP P-056: Mark all notifications read ────────────────────────────────
  it('marks all notifications as read for user', async () => {
    pool.query.mockResolvedValueOnce({ rows: [] });

    const req = { user: { id: USER_ID } };
    const res = mockRes();
    markAllAsRead(req, res, jest.fn());
    await flush();

    expect(pool.query).toHaveBeenCalledWith(
      expect.stringContaining('SET is_read = TRUE'),
      [USER_ID]
    );
  });
});
