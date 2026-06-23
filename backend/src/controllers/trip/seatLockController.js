const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const { emitTripUpdated } = require('../../socket/realtimeEmitter');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function requireUuid(id) {
  if (!id || !UUID_RE.test(id)) throw ApiError.badRequest('Invalid trip ID');
}

/**
 * Read the active locked seat numbers for a trip. Shared by the booking + seat
 * read paths. Returns [] (never throws) when the table doesn't exist yet
 * (pre-migration) so every caller stays backward compatible.
 *
 * @param {object} db  pool or a transaction client
 * @param {string} tripId
 * @returns {Promise<number[]>}
 */
async function getLockedSeatNumbers(db, tripId) {
  try {
    const res = await db.query(
      'SELECT seat_number FROM trip_seat_locks WHERE trip_id = $1',
      [tripId]
    );
    return res.rows
      .map(r => (typeof r.seat_number === 'number' ? r.seat_number : parseInt(r.seat_number, 10)))
      .filter(n => Number.isInteger(n) && n >= 2);
  } catch (e) {
    if (e.code === '42P01') return []; // table missing pre-migration → no locks
    throw e;
  }
}

/**
 * Normalize a requested seat_numbers body field into a sorted, de-duplicated
 * list of integers. Throws on an empty/invalid payload.
 */
function normalizeSeatNumbers(raw) {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw ApiError.badRequest('seat_numbers (non-empty array) is required.');
  }
  const seats = [];
  for (const s of raw) {
    const n = typeof s === 'number' ? s : parseInt(s, 10);
    if (!Number.isInteger(n)) {
      throw ApiError.badRequest('seat_numbers must be whole numbers.');
    }
    seats.push(n);
  }
  return [...new Set(seats)].sort((a, b) => a - b);
}

/**
 * Lock (reserve) one or more of YOUR OWN ride's unbooked seats so no passenger
 * can book them. Independent-driver feature — e.g. holding a seat for a relative.
 * POST /api/trips/:id/lock-seats   Body: { seat_numbers: number[], note?: string }
 *
 * Rules (all enforced atomically under a row lock on the trip):
 *  - Caller must be the trip's own driver.
 *  - Trip must be 'scheduled' and not yet departed.
 *  - Seat 1 (driver) can never be locked; seats must be within capacity.
 *  - A seat already booked / pending / locked cannot be locked again.
 * Either ALL requested seats lock, or none (no partial state).
 */
const lockSeats = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;
  const seatNumbers = normalizeSeatNumbers(req.body && req.body.seat_numbers);
  const note = (req.body && req.body.note != null)
    ? String(req.body.note).trim().slice(0, 80)
    : null;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Lock the trip row so a concurrent booking/lock serializes behind us.
    const tripRes = await client.query(
      `SELECT id, status, departure_time, available_seats,
              total_capacity AS total_seats
       FROM trips
       WHERE id = $1 AND driver_id = $2
       FOR UPDATE`,
      [tripId, driverId]
    );
    if (tripRes.rows.length === 0) {
      await client.query('ROLLBACK');
      throw ApiError.notFound('Ride not found, or you are not its driver.');
    }
    const trip = tripRes.rows[0];

    if (trip.status !== 'scheduled') {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Seats can only be reserved while the ride is scheduled.');
    }
    if (new Date(trip.departure_time).getTime() <= Date.now()) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('This ride has already departed. Seats cannot be reserved now.');
    }

    const totalSeats = trip.total_seats ?? 0;
    for (const seat of seatNumbers) {
      if (seat < 2) {
        await client.query('ROLLBACK');
        throw ApiError.badRequest('Seat 1 is the driver seat and cannot be reserved.');
      }
      if (seat > totalSeats) {
        await client.query('ROLLBACK');
        throw ApiError.badRequest(`Seat ${seat} does not exist on this ride (max ${totalSeats}).`);
      }
    }

    // Seats taken by an active booking (confirmed OR pending) cannot be locked.
    const bookingRes = await client.query(
      `SELECT seat_numbers FROM bookings
       WHERE trip_id = $1 AND status IN ('confirmed', 'pending')`,
      [tripId]
    );
    const takenSet = new Set();
    for (const row of bookingRes.rows) {
      (row.seat_numbers || []).forEach(s => {
        const n = typeof s === 'number' ? s : parseInt(s, 10);
        if (Number.isInteger(n)) takenSet.add(n);
      });
    }
    for (const seat of seatNumbers) {
      if (takenSet.has(seat)) {
        await client.query('ROLLBACK');
        throw ApiError.badRequest(`Seat ${seat} is already booked by a passenger and cannot be reserved.`);
      }
    }

    // Already-locked seats cannot be locked again.
    const alreadyLocked = new Set(await getLockedSeatNumbers(client, tripId));
    for (const seat of seatNumbers) {
      if (alreadyLocked.has(seat)) {
        await client.query('ROLLBACK');
        throw ApiError.badRequest(`Seat ${seat} is already reserved.`);
      }
    }

    // Insert all locks. ON CONFLICT guards against a race we already filtered.
    let inserted = 0;
    for (const seat of seatNumbers) {
      const ins = await client.query(
        `INSERT INTO trip_seat_locks (trip_id, seat_number, note, created_by)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (trip_id, seat_number) DO NOTHING`,
        [tripId, seat, note, driverId]
      );
      inserted += ins.rowCount;
    }

    // Keep available_seats consistent so search / details show the true count.
    if (inserted > 0) {
      await client.query(
        'UPDATE trips SET available_seats = GREATEST(available_seats - $1, 0) WHERE id = $2',
        [inserted, tripId]
      );
    }

    await client.query('COMMIT');

    emitTripUpdated(tripId, { reason: 'seats_locked', seats: seatNumbers });

    const locked = await getLockedSeatNumbers(pool, tripId);
    ApiResponse.success(
      { locked_seats: locked.sort((a, b) => a - b) },
      inserted === 1 ? 'Seat reserved.' : `${inserted} seats reserved.`
    ).send(res);
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) { /* already rolled back */ }
    throw err;
  } finally {
    client.release();
  }
});

/**
 * Release one or more seats you previously reserved so passengers can book them.
 * POST /api/trips/:id/unlock-seats   Body: { seat_numbers: number[] }
 * Idempotent: seats that aren't locked are simply ignored.
 */
const unlockSeats = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;
  const seatNumbers = normalizeSeatNumbers(req.body && req.body.seat_numbers);

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tripRes = await client.query(
      `SELECT id, status, total_capacity AS total_seats
       FROM trips
       WHERE id = $1 AND driver_id = $2
       FOR UPDATE`,
      [tripId, driverId]
    );
    if (tripRes.rows.length === 0) {
      await client.query('ROLLBACK');
      throw ApiError.notFound('Ride not found, or you are not its driver.');
    }
    const totalSeats = tripRes.rows[0].total_seats ?? 0;

    let deleted = 0;
    try {
      const del = await client.query(
        'DELETE FROM trip_seat_locks WHERE trip_id = $1 AND seat_number = ANY($2::int[]) RETURNING seat_number',
        [tripId, seatNumbers]
      );
      deleted = del.rowCount;
    } catch (e) {
      if (e.code !== '42P01') throw e; // table missing → nothing to unlock
    }

    // Give the freed seats back to the available pool (clamped to capacity).
    if (deleted > 0) {
      await client.query(
        'UPDATE trips SET available_seats = LEAST(available_seats + $1, $2) WHERE id = $3',
        [deleted, totalSeats, tripId]
      );
    }

    await client.query('COMMIT');

    if (deleted > 0) emitTripUpdated(tripId, { reason: 'seats_unlocked', seats: seatNumbers });

    const locked = await getLockedSeatNumbers(pool, tripId);
    ApiResponse.success(
      { locked_seats: locked.sort((a, b) => a - b) },
      deleted > 0
        ? (deleted === 1 ? 'Seat released.' : `${deleted} seats released.`)
        : 'No reserved seats to release.'
    ).send(res);
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) { /* already rolled back */ }
    throw err;
  } finally {
    client.release();
  }
});

module.exports = {
  lockSeats,
  unlockSeats,
  getLockedSeatNumbers,
};
