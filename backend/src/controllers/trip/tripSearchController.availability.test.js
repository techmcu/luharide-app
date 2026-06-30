/**
 * Regression lock for the "full ride still shows Book" bug.
 *
 * THE BUG: search trusted the denormalised trips.available_seats column. When
 * that column drifted high or was NULL (legacy rows → COALESCE fell back to the
 * full total_capacity), a fully-booked independent-driver cab kept showing a
 * live "Book" button instead of "Ride Full".
 *
 * THE FIX: computeTrueAvailability recomputes availability from live bookings +
 * active seat locks (the same source the seat-selection screen uses):
 *   available = total_capacity − 1 (driver) − distinct taken passenger seats.
 * These tests pin that math and the best-effort fallbacks so search can never
 * again present a full ride as bookable.
 */

jest.mock('../../config/database', () => ({
  pool: {},
  queryRead: jest.fn(),
}));
jest.mock('../../config/logger', () => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn(), debug: jest.fn() }));
jest.mock('./seatLockController', () => ({ getLockedSeatNumbers: jest.fn().mockResolvedValue([]) }));
jest.mock('../../services/olaMapsService', () => ({ isValidLatLng: jest.fn(() => true) }));

const { queryRead } = require('../../config/database');
const { computeTrueAvailability } = require('./tripSearchController');

beforeEach(() => jest.clearAllMocks());

describe('computeTrueAvailability', () => {
  it('marks a fully-booked cab as 0 even if the stored column drifted high', async () => {
    // 7-seat cab → 6 bookable. All 6 passenger seats (2..7) booked → available 0.
    queryRead.mockResolvedValueOnce({ rows: [{ trip_id: 'a', taken: '6' }] });
    const map = await computeTrueAvailability([
      { id: 'a', total_capacity: 7, available_seats: 5 /* stale, ignored */ },
    ]);
    expect(map.get('a')).toBe(0);
  });

  it('counts driver-locked seats as taken (cab full via locks, no bookings)', async () => {
    // total_capacity 5 → 4 bookable; 4 seats locked → 0 available.
    queryRead.mockResolvedValueOnce({ rows: [{ trip_id: 'b', taken: '4' }] });
    const map = await computeTrueAvailability([{ id: 'b', total_capacity: 5 }]);
    expect(map.get('b')).toBe(0);
  });

  it('returns the real remaining seats for a partly-booked ride', async () => {
    // 7 cap → 6 bookable; 2 taken → 4 left.
    queryRead.mockResolvedValueOnce({ rows: [{ trip_id: 'c', taken: '2' }] });
    const map = await computeTrueAvailability([{ id: 'c', total_capacity: 7 }]);
    expect(map.get('c')).toBe(4);
  });

  it('treats a ride with no bookings/locks as fully available (cap − driver)', async () => {
    queryRead.mockResolvedValueOnce({ rows: [] }); // nothing taken
    const map = await computeTrueAvailability([{ id: 'd', total_capacity: 4 }]);
    expect(map.get('d')).toBe(3);
  });

  it('never returns a negative count', async () => {
    queryRead.mockResolvedValueOnce({ rows: [{ trip_id: 'e', taken: '99' }] });
    const map = await computeTrueAvailability([{ id: 'e', total_capacity: 4 }]);
    expect(map.get('e')).toBe(0);
  });

  it('skips rows with unknown capacity so callers keep the stored column', async () => {
    queryRead.mockResolvedValueOnce({ rows: [] });
    const map = await computeTrueAvailability([{ id: 'f', total_capacity: null }]);
    expect(map.has('f')).toBe(false);
  });

  it('makes no query and returns an empty map when there are no candidate rows', async () => {
    const map = await computeTrueAvailability([]);
    expect(map.size).toBe(0);
    expect(queryRead).not.toHaveBeenCalled();
  });

  it('falls back to bookings-only when trip_seat_locks is not migrated yet', async () => {
    const missing = Object.assign(new Error('relation "trip_seat_locks" does not exist'), { code: '42P01' });
    queryRead
      .mockRejectedValueOnce(missing)                              // locks-aware query fails
      .mockResolvedValueOnce({ rows: [{ trip_id: 'g', taken: '1' }] }); // bookings-only retry
    const map = await computeTrueAvailability([{ id: 'g', total_capacity: 7 }]);
    expect(map.get('g')).toBe(5);
    expect(queryRead).toHaveBeenCalledTimes(2);
  });

  it('returns an empty map (column fallback) on an unexpected query error', async () => {
    queryRead.mockRejectedValueOnce(Object.assign(new Error('boom'), { code: '08006' }));
    const map = await computeTrueAvailability([{ id: 'h', total_capacity: 7 }]);
    expect(map.size).toBe(0);
  });
});
