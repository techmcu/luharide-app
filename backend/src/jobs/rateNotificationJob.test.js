/**
 * Rate notification background job — SOP BG-001→003
 * DB, socket, and advisory lock are mocked — no real database connection.
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
jest.mock('../utils/telegramAlert', () => ({
  sendTelegramAlert: jest.fn(),
  formatJobAlert: jest.fn(),
}));
jest.mock('./pgAdvisoryTryLock', () => ({
  withPgAdvisoryTryLock: jest.fn(async (_pool, _ns, _key, fn) => {
    const client = {
      query: jest.fn(),
    };
    mockClient = client;
    await fn(client);
  }),
  JOB_NS: 100,
  JOB_RATE_NOTIFICATIONS: 3,
}));

let mockClient;
const { emitNotificationToUser } = require('../socket/realtimeEmitter');
const { run } = require('./rateNotificationJob');

describe('rateNotificationJob.run', () => {
  beforeEach(() => jest.clearAllMocks());

  it('does nothing when no pending notifications', async () => {
    const { withPgAdvisoryTryLock } = require('./pgAdvisoryTryLock');
    withPgAdvisoryTryLock.mockImplementation(async (_p, _ns, _key, fn) => {
      const client = { query: jest.fn().mockResolvedValue({ rows: [] }) };
      await fn(client);
    });

    await run();
    expect(emitNotificationToUser).not.toHaveBeenCalled();
  });

  it('sends notifications for due rows with completed booking', async () => {
    const { withPgAdvisoryTryLock } = require('./pgAdvisoryTryLock');
    withPgAdvisoryTryLock.mockImplementation(async (_p, _ns, _key, fn) => {
      const client = {
        query: jest.fn()
          .mockResolvedValueOnce({ rows: [{
            id: 'pn1', booking_id: 'bk1', passenger_id: 'p1', driver_id: 'd1',
          }] })
          .mockResolvedValueOnce({ rows: [{ status: 'completed' }] })  // booking status
          .mockResolvedValueOnce({ rows: [                              // INSERT notifications
            { id: 'n1', user_id: 'p1', type: 'rate_ride' },
            { id: 'n2', user_id: 'd1', type: 'rate_ride' },
          ] })
          .mockResolvedValueOnce({ rows: [] }),  // DELETE pending
      };
      await fn(client);
    });

    await run();
    expect(emitNotificationToUser).toHaveBeenCalledTimes(2);
  });

  it('skips cancelled booking and deletes pending row', async () => {
    const { withPgAdvisoryTryLock } = require('./pgAdvisoryTryLock');
    withPgAdvisoryTryLock.mockImplementation(async (_p, _ns, _key, fn) => {
      const client = {
        query: jest.fn()
          .mockResolvedValueOnce({ rows: [{
            id: 'pn1', booking_id: 'bk1', passenger_id: 'p1', driver_id: 'd1',
          }] })
          .mockResolvedValueOnce({ rows: [{ status: 'cancelled' }] })  // cancelled
          .mockResolvedValueOnce({ rows: [] }),  // DELETE
      };
      await fn(client);
    });

    await run();
    expect(emitNotificationToUser).not.toHaveBeenCalled();
  });
});
