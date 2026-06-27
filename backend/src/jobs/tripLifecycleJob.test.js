/**
 * Trip lifecycle background job — auto-start, auto-complete, pending expiry
 * SOP: BG-004→006
 * DB, socket, and advisory lock are mocked — no real database connection.
 */

jest.mock('../config/database', () => ({
  pool: { query: jest.fn() },
}));
jest.mock('../socket/realtimeEmitter', () => ({
  emitNotificationToUser: jest.fn(),
  emitTripUpdated: jest.fn(),
}));
jest.mock('../config/logger', () => ({
  info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn(),
}));
jest.mock('../config/retentionConfig', () => ({
  tripSearchGraceMinutesAfterDeparture: 30,
}));
jest.mock('../utils/telegramAlert', () => ({
  sendTelegramAlert: jest.fn(),
  formatJobAlert: jest.fn(),
}));
jest.mock('./pgAdvisoryTryLock', () => ({
  withPgAdvisoryTryLock: jest.fn(),
  JOB_NS: 100,
  JOB_TRIP_LIFECYCLE: 4,
}));

const { emitTripUpdated, emitNotificationToUser } = require('../socket/realtimeEmitter');
const { withPgAdvisoryTryLock } = require('./pgAdvisoryTryLock');
const { run } = require('./tripLifecycleJob');

describe('tripLifecycleJob.run', () => {
  beforeEach(() => jest.clearAllMocks());

  it('auto-starts trips and cancels pending bookings', async () => {
    withPgAdvisoryTryLock.mockImplementation(async (_p, _ns, _key, fn) => {
      const client = {
        query: jest.fn()
          // auto-start: UPDATE trips scheduled → in_progress
          .mockResolvedValueOnce({ rows: [{ id: 't1', driver_id: 'd1' }], rowCount: 1 })
          // cancel pending bookings for t1
          .mockResolvedValueOnce({ rows: [{ id: 'bk1', passenger_id: 'p1', seat_numbers: [2, 3] }] })
          // restore seats
          .mockResolvedValueOnce({ rows: [] })
          // notify passenger
          .mockResolvedValueOnce({ rows: [{ id: 'n1', user_id: 'p1' }] })
          // notify driver (trip auto-started)
          .mockResolvedValueOnce({ rows: [{ id: 'n2', user_id: 'd1' }] })
          // auto-finish: UPDATE trips in_progress → completed
          .mockResolvedValueOnce({ rows: [], rowCount: 0 })
          // union schedules auto-complete
          .mockResolvedValue({ rows: [], rowCount: 0 }),
      };
      await fn(client);
    });

    await run();

    expect(emitTripUpdated).toHaveBeenCalledWith('t1', expect.objectContaining({ status: 'in_progress' }));
    expect(emitNotificationToUser).toHaveBeenCalled();
  });

  it('auto-completes in_progress trips past arrival', async () => {
    withPgAdvisoryTryLock.mockImplementation(async (_p, _ns, _key, fn) => {
      const client = {
        query: jest.fn()
          // auto-start: none
          .mockResolvedValueOnce({ rows: [], rowCount: 0 })
          // auto-finish: 1 trip completed
          .mockResolvedValueOnce({ rows: [{ id: 't2' }], rowCount: 1 })
          // complete confirmed bookings for t2
          .mockResolvedValueOnce({ rows: [{ id: 'bk2', passenger_id: 'p2' }] })
          // rate reminders for completed
          .mockResolvedValue({ rows: [] }),
      };
      await fn(client);
    });

    await run();
  });

  it('does nothing when no trips to process', async () => {
    withPgAdvisoryTryLock.mockImplementation(async (_p, _ns, _key, fn) => {
      const client = {
        query: jest.fn()
          .mockResolvedValueOnce({ rows: [], rowCount: 0 })   // auto-start: none
          .mockResolvedValueOnce({ rows: [], rowCount: 0 })   // auto-finish: none
          .mockResolvedValue({ rows: [], rowCount: 0 }),       // union schedules: none
      };
      await fn(client);
    });

    await run();

    expect(emitTripUpdated).not.toHaveBeenCalled();
  });

  it('auto-completes union schedules past their journey time', async () => {
    let captured;
    withPgAdvisoryTryLock.mockImplementation(async (_p, _ns, _key, fn) => {
      const client = {
        query: jest.fn()
          .mockResolvedValueOnce({ rows: [], rowCount: 0 })            // auto-start: none
          .mockResolvedValueOnce({ rows: [], rowCount: 0 })            // auto-finish: none
          .mockResolvedValueOnce({ rows: [{ id: 'us1' }], rowCount: 1 }), // union complete
      };
      captured = client;
      await fn(client);
    });

    await run();

    const unionCall = captured.query.mock.calls.find(
      ([sql]) => typeof sql === 'string' && sql.includes('union_schedules')
    );
    expect(unionCall).toBeTruthy();
  });
});
