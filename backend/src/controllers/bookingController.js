const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { emitTripUpdated, emitNotificationToUser } = require('../socket/realtimeEmitter');

function normalizeIdempotencyKey(key) {
  if (key == null || typeof key !== 'string') return '';
  return key.trim().slice(0, 128);
}

function sendBookingCreated(res, booking, message, statusCode = 201) {
  const payload = {
    booking: {
      id: booking.id,
      trip_id: booking.trip_id,
      seat_numbers: booking.seat_numbers,
      status: booking.status,
      total_amount: parseFloat(booking.total_amount),
      created_at: booking.created_at
    }
  };
  if (statusCode === 201) {
    ApiResponse.created(payload, message).send(res);
  } else {
    ApiResponse.success(payload, message).send(res);
  }
}

/**
 * Create a booking (Passenger)
 * Uses transaction + row lock to prevent race: 2 users booking same seat at same time
 * POST /api/bookings
 * Optional: Idempotency-Key header or body idempotency_key — duplicate safe retries (run migration 030).
 */
const createBooking = asyncHandler(async (req, res) => {
  const { trip_id, seat_numbers } = req.body;
  const passengerId = req.user.id;
  const idemKey = normalizeIdempotencyKey(req.headers['idempotency-key'] || req.body.idempotency_key);

  if (!trip_id || !seat_numbers || !Array.isArray(seat_numbers) || seat_numbers.length === 0) {
    throw ApiError.badRequest('trip_id and seat_numbers (array) are required');
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    if (idemKey) {
      const existing = await client.query(
        'SELECT * FROM bookings WHERE passenger_id = $1 AND idempotency_key = $2',
        [passengerId, idemKey]
      );
      if (existing.rows.length > 0) {
        const row = existing.rows[0];
        const sameTrip = String(row.trip_id) === String(trip_id);
        const prevSeats = [...(row.seat_numbers || [])].sort((a, b) => a - b);
        const reqSeats = [...new Set(seat_numbers.filter(s => Number.isInteger(s)))].sort((a, b) => a - b);
        const seatsMatch = prevSeats.length === reqSeats.length && prevSeats.every((s, i) => s === reqSeats[i]);
        if (sameTrip && seatsMatch) {
          await client.query('COMMIT');
          const msg = row.status === 'pending'
            ? 'Booking request already sent.'
            : 'Booking already confirmed.';
          return sendBookingCreated(res, row, msg, 200);
        }
        await client.query('ROLLBACK');
        throw ApiError.conflict('Idempotency key was already used with different trip or seats.');
      }
    }

    // Lock trip row to prevent race – first request wins
    const tripResult = await client.query(
      'SELECT * FROM trips WHERE id = $1 AND status = $2 FOR UPDATE',
      [trip_id, 'scheduled']
    );

    if (tripResult.rows.length === 0) {
      await client.query('ROLLBACK');
      throw ApiError.notFound('Trip not found or not available');
    }

    const trip = tripResult.rows[0];
    const farePerSeat = parseFloat(trip.fare_per_seat);
    const totalSeats = trip.total_seats ?? trip.total_capacity ?? 0;
    const availableSeats = trip.available_seats ?? trip.total_capacity ?? 0;
    const requireApproval = trip.require_approval === false ? false : true;

    if (trip.driver_id != null && String(trip.driver_id) === String(passengerId)) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest(
        'You cannot book seats on a ride you created. Use another account to book as a passenger.'
      );
    }

    const validSeats = seat_numbers.filter(s => Number.isInteger(s) && s >= 1 && s <= totalSeats);
    const uniqueSeats = [...new Set(validSeats)];

    if (uniqueSeats.includes(1)) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Seat 1 is reserved for the driver and cannot be booked');
    }

    if (uniqueSeats.length !== seat_numbers.length) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Invalid or duplicate seat numbers');
    }

    if (uniqueSeats.length > availableSeats) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest(`Only ${availableSeats} seats available`);
    }

    // Check seats – both confirmed and pending block the seat
    const existingBookings = await client.query(
      'SELECT seat_numbers FROM bookings WHERE trip_id = $1 AND status IN ($2, $3)',
      [trip_id, 'confirmed', 'pending']
    );

    const bookedSeats = new Set();
    for (const row of existingBookings.rows) {
      (row.seat_numbers || []).forEach(s => bookedSeats.add(s));
    }

    for (const seat of uniqueSeats) {
      if (bookedSeats.has(seat)) {
        await client.query('ROLLBACK');
        throw ApiError.badRequest(`Seat ${seat} is already booked or pending`);
      }
    }

    const totalAmount = uniqueSeats.length * farePerSeat;
    const bookingStatus = requireApproval ? 'pending' : 'confirmed';

    let result;
    try {
      result = await client.query(
        `INSERT INTO bookings (trip_id, passenger_id, seat_numbers, status, total_amount, idempotency_key)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING *`,
        [trip_id, passengerId, uniqueSeats, bookingStatus, totalAmount, idemKey || null]
      );
    } catch (insErr) {
      if (
        insErr.code === '42703' &&
        (String(insErr.message || '').includes('idempotency_key') || insErr.column === 'idempotency_key')
      ) {
        result = await client.query(
          `INSERT INTO bookings (trip_id, passenger_id, seat_numbers, status, total_amount)
           VALUES ($1, $2, $3, $4, $5)
           RETURNING *`,
          [trip_id, passengerId, uniqueSeats, bookingStatus, totalAmount]
        );
      } else if (insErr.code === '23505' && idemKey) {
        await client.query('ROLLBACK');
        const replay = await pool.query(
          'SELECT * FROM bookings WHERE passenger_id = $1 AND idempotency_key = $2',
          [passengerId, idemKey]
        );
        if (replay.rows.length > 0) {
          const row = replay.rows[0];
          const msg = row.status === 'pending'
            ? 'Booking request already sent.'
            : 'Booking already confirmed.';
          return sendBookingCreated(res, row, msg, 200);
        }
        throw insErr;
      }
      throw insErr;
    }

    const booking = result.rows[0];

    if (bookingStatus === 'confirmed') {
      await client.query(
        'UPDATE trips SET available_seats = available_seats - $1 WHERE id = $2',
        [uniqueSeats.length, trip_id]
      );
      await client.query(
        'UPDATE bookings SET confirmed_at = NOW() WHERE id = $1',
        [booking.id]
      );
    }

    await client.query('COMMIT');

    emitTripUpdated(trip_id, { bookingId: booking.id, status: bookingStatus, reason: 'booking_created' });

    // Rate reminders: union/legacy = 4h after confirm. Independent driver trips = trip departure_time + 4h (after scheduled ride start).
    if (bookingStatus === 'confirmed') {
      try {
        const independent = trip.created_source === 'independent_driver' && trip.departure_time;
        if (independent) {
          await pool.query(
            `INSERT INTO pending_rate_notifications (booking_id, passenger_id, driver_id, send_after)
             VALUES ($1, $2, $3, $4::timestamp + INTERVAL '4 hours')`,
            [booking.id, passengerId, trip.driver_id, trip.departure_time]
          );
        } else {
          await pool.query(
            `INSERT INTO pending_rate_notifications (booking_id, passenger_id, driver_id, send_after)
             VALUES ($1, $2, $3, NOW() + INTERVAL '4 hours')`,
            [booking.id, passengerId, trip.driver_id]
          );
        }
      } catch (err) {
        if (err.code === '42P01') {
          const dataJson = JSON.stringify({ booking_id: booking.id });
          try {
            const fb = await pool.query(
              `INSERT INTO notifications (user_id, type, title, body, data)
               VALUES ($1, 'rate_ride', 'Rate your driver', 'Your ride was confirmed. Rate your driver.', $2::jsonb),
                      ($3, 'rate_ride', 'Rate your passenger', 'A passenger booked your ride. Rate them after the trip.', $2::jsonb)
               RETURNING id, user_id, type, title, body, data, created_at, is_read`,
              [passengerId, dataJson, trip.driver_id]
            );
            for (const row of fb.rows) emitNotificationToUser(row.user_id, row);
          } catch (e) {
            logger.warn('Fallback rate notifications failed:', e.message);
          }
        } else {
          logger.warn('Pending rate notification insert failed:', err.message);
        }
      }
    }

    const message = bookingStatus === 'pending'
      ? 'Booking request sent. Driver will approve shortly.'
      : 'Booking confirmed';

    sendBookingCreated(res, booking, message, 201);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

/**
 * Driver respond to booking (accept/reject)
 * PUT /api/bookings/:id/respond
 */
const respondToBooking = asyncHandler(async (req, res) => {
  const { id: bookingId } = req.params;
  const { action } = req.body; // 'accept' or 'reject'
  const driverId = req.user.id;

  if (!['accept', 'reject'].includes(action)) {
    throw ApiError.badRequest('action must be accept or reject');
  }

  let bookingResult;
  try {
    bookingResult = await pool.query(
      `SELECT b.*, t.driver_id, t.available_seats, t.departure_time, t.created_source
       FROM bookings b
       JOIN trips t ON b.trip_id = t.id
       WHERE b.id = $1`,
      [bookingId]
    );
  } catch (qErr) {
    if (qErr.code === '42703' && (qErr.message || '').includes('created_source')) {
      bookingResult = await pool.query(
        `SELECT b.*, t.driver_id, t.available_seats, t.departure_time
         FROM bookings b
         JOIN trips t ON b.trip_id = t.id
         WHERE b.id = $1`,
        [bookingId]
      );
    } else {
      throw qErr;
    }
  }

  if (bookingResult.rows.length === 0) {
    throw ApiError.notFound('Booking not found');
  }

  const booking = bookingResult.rows[0];
  if (booking.driver_id !== driverId) {
    throw ApiError.forbidden('You can only respond to bookings for your trips');
  }

  if (booking.status !== 'pending') {
    throw ApiError.badRequest('Booking is not pending');
  }

  const seatNums = Array.isArray(booking.seat_numbers) 
    ? booking.seat_numbers 
    : (booking.seat_numbers ? [].concat(booking.seat_numbers) : []);
  const seatCount = seatNums.length;

  if (action === 'reject') {
    await pool.query(
      'UPDATE bookings SET status = $1 WHERE id = $2',
      ['cancelled', bookingId]
    );
    emitTripUpdated(booking.trip_id, { bookingId, status: 'cancelled', reason: 'booking_rejected' });
    return ApiResponse.success(
      { status: 'cancelled' },
      'Booking rejected'
    ).send(res);
  }

  // Accept – check seats are not already confirmed by another booking
  const confirmedBookings = await pool.query(
    `SELECT seat_numbers FROM bookings 
     WHERE trip_id = $1 AND status = 'confirmed' AND id != $2`,
    [booking.trip_id, bookingId]
  );

  const takenSeats = new Set();
  for (const row of confirmedBookings.rows) {
    (row.seat_numbers || []).forEach(s => takenSeats.add(s));
  }

  for (const seat of seatNums) {
    if (takenSeats.has(seat)) {
      await pool.query(
        'UPDATE bookings SET status = $1 WHERE id = $2',
        ['cancelled', bookingId]
      );
      throw ApiError.badRequest(`Seat ${seat} is no longer available. Another booking was already approved.`);
    }
  }

  const availableSeats = parseInt(booking.available_seats, 10) || 0;
  if (seatCount > availableSeats) {
    throw ApiError.badRequest('Not enough seats available');
  }

  await pool.query(
    `UPDATE bookings SET status = 'confirmed', confirmed_at = NOW() WHERE id = $1`,
    [bookingId]
  );
  await pool.query(
    'UPDATE trips SET available_seats = available_seats - $1 WHERE id = $2',
    [seatCount, booking.trip_id]
  );

  // Cancel other pending bookings that overlap with these seats
  const otherPending = await pool.query(
    `SELECT id, seat_numbers FROM bookings 
     WHERE trip_id = $1 AND status = 'pending' AND id != $2`,
    [booking.trip_id, bookingId]
  );

  const approvedSet = new Set(seatNums);
  for (const row of otherPending.rows) {
    const others = row.seat_numbers || [];
    const overlaps = others.some(s => approvedSet.has(s));
    if (overlaps) {
      await pool.query(
        'UPDATE bookings SET status = $1 WHERE id = $2',
        ['cancelled', row.id]
      );
    }
  }

  // Independent driver trips: rate reminder at scheduled departure + 4h. Union/legacy: 3 min after accept.
  try {
    const independent = booking.created_source === 'independent_driver' && booking.departure_time;
    if (independent) {
      await pool.query(
        `INSERT INTO pending_rate_notifications (booking_id, passenger_id, driver_id, send_after)
         VALUES ($1, $2, $3, $4::timestamp + INTERVAL '4 hours')`,
        [bookingId, booking.passenger_id, booking.driver_id, booking.departure_time]
      );
    } else {
      await pool.query(
        `INSERT INTO pending_rate_notifications (booking_id, passenger_id, driver_id, send_after)
         VALUES ($1, $2, $3, NOW() + INTERVAL '3 minutes')`,
        [bookingId, booking.passenger_id, booking.driver_id]
      );
    }
  } catch (err) {
    if (err.code === '42P01') {
      const dataJson = JSON.stringify({ booking_id: bookingId });
      try {
        const fb = await pool.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'rate_ride', 'Rate your driver', 'Your ride was confirmed. You can rate 4 min after confirm.', $2::jsonb),
                  ($3, 'rate_ride', 'Rate your passenger', 'You accepted a booking. You can rate 4 min after confirm.', $2::jsonb)
           RETURNING id, user_id, type, title, body, data, created_at, is_read`,
          [booking.passenger_id, dataJson, booking.driver_id]
        );
        for (const row of fb.rows) emitNotificationToUser(row.user_id, row);
      } catch (e) {
        logger.warn('Fallback rate notifications failed:', e.message);
      }
    } else {
      logger.warn('Pending rate notification insert failed:', err.message);
    }
  }

  emitTripUpdated(booking.trip_id, { bookingId, status: 'confirmed', reason: 'booking_confirmed' });

  ApiResponse.success(
    { status: 'confirmed' },
    'Booking approved'
  ).send(res);
});

/**
 * Get my bookings (Passenger)
 * GET /api/bookings/my-bookings?days=30&page=1&limit=20
 *
 * Params:
 *   days  — how many past days to fetch (default 30, max 90, use 0 for all within retention)
 *   page  — page number (default 1)
 *   limit — results per page (default 20, max 50)
 *
 * Tiered display strategy:
 *   - Default: last 30 days (fast, relevant)
 *   - User taps "Load older": pass days=90 (or days=0 for all retained records)
 *   - Records older than 90 days are purged by cron — intentionally not shown
 */
const getMyBookings = asyncHandler(async (req, res) => {
  const passengerId = req.user.id;
  const days  = Math.min(60, Math.max(0, parseInt(req.query.days,  10) || 30));
  const page  = Math.max(1,  parseInt(req.query.page,  10) || 1);
  const limit = Math.min(50, Math.max(1, parseInt(req.query.limit, 10) || 20));
  const offset = (page - 1) * limit;

  // days=0 → no date filter (show everything within retention window)
  const dateClause = days > 0
    ? `AND b.created_at >= NOW() - INTERVAL '${days} days'`
    : '';

  const [dataRes, countRes] = await Promise.all([
    pool.query(
      `SELECT
        b.id, b.trip_id, b.seat_numbers, b.status, b.total_amount, b.created_at,
        t.from_location, t.to_location, t.departure_time, t.fare_per_seat,
        t.vehicle_number, t.total_capacity AS total_seats,
        u.name  AS driver_name,  u.phone AS driver_phone,
        u.email AS driver_email, u.whatsapp_number AS driver_whatsapp,
        u.bio   AS driver_bio,   u.luggage_allowance_per_passenger AS driver_luggage_allowance
       FROM bookings b
       JOIN trips t ON b.trip_id = t.id
       LEFT JOIN users u ON t.driver_id = u.id
       WHERE b.passenger_id = $1
         ${dateClause}
       ORDER BY b.created_at DESC
       LIMIT $2 OFFSET $3`,
      [passengerId, limit, offset]
    ),
    pool.query(
      `SELECT COUNT(*)::int AS total
       FROM bookings b
       WHERE b.passenger_id = $1
         ${dateClause}`,
      [passengerId]
    ),
  ]);

  const total      = countRes.rows[0].total;
  const totalPages = Math.ceil(total / limit);

  const bookings = dataRes.rows.map(row => ({
    id:             row.id,
    trip_id:        row.trip_id,
    seat_numbers:   row.seat_numbers,
    status:         row.status,
    total_amount:   parseFloat(row.total_amount),
    created_at:     row.created_at,
    from_location:  row.from_location,
    to_location:    row.to_location,
    departure_time: row.departure_time,
    fare_per_seat:  parseFloat(row.fare_per_seat),
    vehicle_number: row.vehicle_number,
    driver: row.status === 'confirmed' ? {
      name:                          row.driver_name,
      phone:                         row.driver_phone,
      email:                         row.driver_email,
      whatsapp_number:               row.driver_whatsapp,
      bio:                           row.driver_bio || null,
      luggage_allowance_per_passenger: row.driver_luggage_allowance || null,
    } : null,
  }));

  ApiResponse.success(
    { bookings, total, page, limit, total_pages: totalPages, days_filter: days },
    'Bookings retrieved'
  ).send(res);
});

/** Cancel policy: for testing = 2 minutes before departure. Production can use 2 hours. */
const CANCEL_BEFORE_DEPARTURE_MINUTES = 2;

/**
 * Cancel booking (Passenger only)
 * POST /api/bookings/:id/cancel
 * Body: { reason?: string }
 * Pending: always allowed. Confirmed: allowed until 2 min before departure (testing).
 */
const cancelBooking = asyncHandler(async (req, res) => {
  const bookingId = req.params.id;
  const passengerId = req.user.id;
  const reason = (req.body && req.body.reason != null) ? String(req.body.reason).trim() : null;

  const bookingResult = await pool.query(
    `SELECT b.id, b.trip_id, b.passenger_id, b.status, b.seat_numbers,
            t.driver_id, t.departure_time
     FROM bookings b
     JOIN trips t ON b.trip_id = t.id
     WHERE b.id = $1`,
    [bookingId]
  );

  if (bookingResult.rows.length === 0) {
    throw ApiError.notFound('Booking not found');
  }

  const booking = bookingResult.rows[0];
  if (booking.passenger_id !== passengerId) {
    throw ApiError.forbidden('You can only cancel your own booking');
  }

  if (booking.status === 'cancelled') {
    throw ApiError.badRequest('Booking is already cancelled');
  }

  const departureTime = new Date(booking.departure_time).getTime();
  const now = Date.now();

  // After ride start: cancel disabled (both sides rule)
  if (now >= departureTime) {
    throw ApiError.badRequest('Ride has already started. Cancellation not allowed.');
  }

  // Within 2 min of departure: cancel disabled
  const cutoffMs = CANCEL_BEFORE_DEPARTURE_MINUTES * 60 * 1000;
  if (booking.status === 'confirmed' && (departureTime - now) < cutoffMs) {
    throw ApiError.badRequest(
      `Cancellation not allowed. Cancel at least ${CANCEL_BEFORE_DEPARTURE_MINUTES} minutes before departure.`
    );
  }

  const seatCount = Array.isArray(booking.seat_numbers) ? booking.seat_numbers.length : 0;

  await pool.query(
    `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(), cancellation_reason = $2 WHERE id = $1`,
    [bookingId, reason || null]
  );

  if (booking.status === 'confirmed' && seatCount > 0) {
    await pool.query(
      'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
      [seatCount, booking.trip_id]
    );
  }

  try {
    const nRes = await pool.query(
      `INSERT INTO notifications (user_id, type, title, body)
       VALUES ($1, 'booking_cancelled', 'Booking cancelled', $2)
       RETURNING id, user_id, type, title, body, created_at, is_read`,
      [booking.driver_id, `A passenger cancelled their booking.${reason ? ` Reason: ${reason}` : ''}`]
    );
    if (nRes.rows[0]) {
      emitNotificationToUser(nRes.rows[0].user_id, nRes.rows[0]);
    }
  } catch (e) {
    logger.warn('Driver cancel notification failed:', e.message);
  }

  emitTripUpdated(booking.trip_id, { bookingId, status: 'cancelled', reason: 'passenger_cancelled' });

  ApiResponse.success(
    { status: 'cancelled' },
    'Booking cancelled'
  ).send(res);
});

module.exports = {
  createBooking,
  respondToBooking,
  getMyBookings,
  cancelBooking
};
