const { pool } = require('../config/database');
const ApiError = require('../utils/ApiError');
const ApiResponse = require('../utils/ApiResponse');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');
const { emitTripUpdated, emitNotificationToUser } = require('../socket/realtimeEmitter');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function requireUuid(id, label = 'ID') {
  if (!id || !UUID_RE.test(id)) throw ApiError.badRequest(`Invalid ${label}`);
}

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

  try {
    const blockCheck = await pool.query(
      `SELECT cancel_blocked_until FROM users WHERE id = $1`,
      [passengerId]
    );
    if (blockCheck.rows[0]?.cancel_blocked_until && new Date(blockCheck.rows[0].cancel_blocked_until) > new Date()) {
      const until = new Date(blockCheck.rows[0].cancel_blocked_until);
      throw ApiError.badRequest(
        `Aapne bahut baar cancel kiya hai. ${until.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })} tak naye booking nahi kar sakte.`
      );
    }
  } catch (e) {
    if (e.statusCode) throw e;
    if (e.code !== '42703') logger.warn('Booking block check failed:', e.message);
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

    // Booking cooldown: 10 min wait after cancelling the same trip
    const cooldownResult = await client.query(
      `SELECT cancelled_at FROM bookings
       WHERE passenger_id = $1 AND trip_id = $2 AND status = 'cancelled'
         AND cancelled_at > NOW() - INTERVAL '10 minutes'
       ORDER BY cancelled_at DESC LIMIT 1`,
      [passengerId, trip_id]
    );
    if (cooldownResult.rows.length > 0) {
      const cancelledAt = new Date(cooldownResult.rows[0].cancelled_at);
      const waitUntil = new Date(cancelledAt.getTime() + 10 * 60 * 1000);
      const minsLeft = Math.ceil((waitUntil - Date.now()) / 60000);
      await client.query('ROLLBACK');
      throw ApiError.badRequest(
        `You cancelled this ride recently. Please wait ${minsLeft} minute${minsLeft === 1 ? '' : 's'} before booking again.`
      );
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

    const depMs = new Date(trip.departure_time).getTime();
    if (depMs <= Date.now()) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('This ride has already departed. You cannot book now.');
    }
    const AUTO_CONFIRM_WITHIN_MINUTES = 2;
    const forceAutoConfirm = (depMs - Date.now()) < AUTO_CONFIRM_WITHIN_MINUTES * 60 * 1000;

    if (trip.driver_id != null && String(trip.driver_id) === String(passengerId)) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest(
        'You cannot book seats on a ride you created. Use another account to book as a passenger.'
      );
    }

    const dupCheck = await client.query(
      `SELECT id FROM bookings WHERE trip_id = $1 AND passenger_id = $2 AND status IN ('pending', 'confirmed') LIMIT 1`,
      [trip_id, passengerId]
    );
    if (dupCheck.rows.length > 0) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('You already have an active booking on this ride.');
    }

    // Independent driver trips require passenger phone — driver needs to contact them
    if (trip.created_source === 'independent_driver') {
      const pRes = await client.query('SELECT phone FROM users WHERE id = $1', [passengerId]);
      const passengerPhone = pRes.rows[0]?.phone;
      if (!passengerPhone || passengerPhone.trim() === '') {
        await client.query('ROLLBACK');
        throw ApiError.badRequest(
          'PHONE_REQUIRED:Please add your phone number in your profile before booking. The driver needs your contact number.'
        );
      }
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
    const bookingStatus = (requireApproval && !forceAutoConfirm) ? 'pending' : 'confirmed';

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

    // Reserve seats for ALL bookings (pending + confirmed) so available_seats is accurate
    await client.query(
      'UPDATE trips SET available_seats = available_seats - $1 WHERE id = $2',
      [uniqueSeats.length, trip_id]
    );

    if (bookingStatus === 'confirmed') {
      await client.query(
        'UPDATE bookings SET confirmed_at = NOW() WHERE id = $1',
        [booking.id]
      );
    }

    await client.query('COMMIT');

    emitTripUpdated(trip_id, { bookingId: booking.id, status: bookingStatus, reason: 'booking_created' });

    if (bookingStatus === 'confirmed') {
      // Notify driver: a new booking was confirmed on their trip
      try {
        const dn = await pool.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'booking_confirmed', 'New booking confirmed!', 'A passenger booked a seat on your ride.', $2::jsonb)
           RETURNING id, user_id, type, title, body, data, created_at, is_read`,
          [trip.driver_id, JSON.stringify({ booking_id: booking.id, trip_id })]
        );
        if (dn.rows[0]) emitNotificationToUser(dn.rows[0].user_id, dn.rows[0]);
      } catch (e) {
        logger.warn('Booking confirmed notification failed:', e.message);
      }

      // Rate reminders: departure_time + 5h (independent) or NOW + 5h (union/legacy)
      try {
        const independent = trip.created_source === 'independent_driver' && trip.departure_time;
        if (independent) {
          await pool.query(
            `INSERT INTO pending_rate_notifications (booking_id, passenger_id, driver_id, send_after)
             VALUES ($1, $2, $3, $4::timestamp + INTERVAL '5 hours')`,
            [booking.id, passengerId, trip.driver_id, trip.departure_time]
          );
        } else {
          await pool.query(
            `INSERT INTO pending_rate_notifications (booking_id, passenger_id, driver_id, send_after)
             VALUES ($1, $2, $3, NOW() + INTERVAL '5 hours')`,
            [booking.id, passengerId, trip.driver_id]
          );
        }
      } catch (err) {
        if (err.code !== '42P01') {
          logger.warn('Pending rate notification insert failed:', err.message);
        }
      }
    } else if (bookingStatus === 'pending') {
      // Notify driver: new booking request needs approval
      try {
        const dn = await pool.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'booking_pending', 'New booking request!', 'A passenger wants to book a seat. Tap to approve or reject.', $2::jsonb)
           RETURNING id, user_id, type, title, body, data, created_at, is_read`,
          [trip.driver_id, JSON.stringify({ booking_id: booking.id, trip_id })]
        );
        if (dn.rows[0]) emitNotificationToUser(dn.rows[0].user_id, dn.rows[0]);
      } catch (e) {
        logger.warn('Booking pending notification failed:', e.message);
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
  requireUuid(bookingId, 'booking ID');
  const { action } = req.body;
  const driverId = req.user.id;

  if (!['accept', 'reject'].includes(action)) {
    throw ApiError.badRequest('action must be accept or reject');
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    let bookingResult;
    try {
      bookingResult = await client.query(
        `SELECT b.*, t.driver_id, t.available_seats, t.departure_time, t.created_source
         FROM bookings b
         JOIN trips t ON b.trip_id = t.id
         WHERE b.id = $1
         FOR UPDATE OF b`,
        [bookingId]
      );
    } catch (qErr) {
      if (qErr.code === '42703' && (qErr.message || '').includes('created_source')) {
        bookingResult = await client.query(
          `SELECT b.*, t.driver_id, t.available_seats, t.departure_time
           FROM bookings b
           JOIN trips t ON b.trip_id = t.id
           WHERE b.id = $1
           FOR UPDATE OF b`,
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

    if (new Date(booking.departure_time).getTime() <= Date.now()) {
      throw ApiError.badRequest('Ride departure time has passed. Cannot respond to this booking now.');
    }

    const seatNums = Array.isArray(booking.seat_numbers)
      ? booking.seat_numbers
      : (booking.seat_numbers ? [].concat(booking.seat_numbers) : []);
    const seatCount = seatNums.length;

    if (action === 'reject') {
      await client.query(
        "UPDATE bookings SET status = 'cancelled' WHERE id = $1",
        [bookingId]
      );
      // Restore seats reserved by the pending booking
      if (seatCount > 0) {
        await client.query(
          'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
          [seatCount, booking.trip_id]
        );
      }
      await client.query('COMMIT');
      emitTripUpdated(booking.trip_id, { bookingId, status: 'cancelled', reason: 'booking_rejected' });

      try {
        const rn = await pool.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'booking_rejected', 'Booking not approved', 'Driver ne aapki booking approve nahi ki. Kripya doosri ride try karein.', $2::jsonb)
           RETURNING id, user_id, type, title, body, data, created_at, is_read`,
          [booking.passenger_id, JSON.stringify({ booking_id: bookingId, trip_id: booking.trip_id })]
        );
        if (rn.rows[0]) emitNotificationToUser(rn.rows[0].user_id, rn.rows[0]);
      } catch (e) {
        logger.warn('Booking rejected notification failed:', e.message);
      }

      return ApiResponse.success({ status: 'cancelled' }, 'Booking rejected').send(res);
    }

    // Lock the trip row for seat count safety
    const tripLock = await client.query(
      'SELECT available_seats FROM trips WHERE id = $1 FOR UPDATE',
      [booking.trip_id]
    );
    const availableSeats = parseInt(tripLock.rows[0]?.available_seats, 10) || 0;

    const confirmedBookings = await client.query(
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
        await client.query(
          "UPDATE bookings SET status = 'cancelled' WHERE id = $1",
          [bookingId]
        );
        if (seatCount > 0) {
          await client.query(
            'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
            [seatCount, booking.trip_id]
          );
        }
        await client.query('COMMIT');
        throw ApiError.badRequest(`Seat ${seat} is no longer available. Another booking was already approved.`);
      }
    }

    if (seatCount > availableSeats) {
      throw ApiError.badRequest('Not enough seats available');
    }

    await client.query(
      "UPDATE bookings SET status = 'confirmed', confirmed_at = NOW() WHERE id = $1",
      [bookingId]
    );
    // No seat decrement here — already reserved at booking creation time

    // Cancel other pending bookings that overlap with these seats
    const otherPending = await client.query(
      `SELECT id, seat_numbers FROM bookings
       WHERE trip_id = $1 AND status = 'pending' AND id != $2`,
      [booking.trip_id, bookingId]
    );

    const approvedSet = new Set(seatNums);
    const autoCancelledPassengers = [];
    for (const row of otherPending.rows) {
      const others = row.seat_numbers || [];
      if (others.some(s => approvedSet.has(s))) {
        await client.query(
          "UPDATE bookings SET status = 'cancelled' WHERE id = $1",
          [row.id]
        );
        // Restore seats reserved by this auto-cancelled pending booking
        if (others.length > 0) {
          await client.query(
            'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
            [others.length, booking.trip_id]
          );
        }
        autoCancelledPassengers.push({ bookingId: row.id, passengerId: row.passenger_id });
      }
    }

    await client.query('COMMIT');

    for (const ac of autoCancelledPassengers) {
      try {
        const acn = await pool.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'booking_auto_cancelled', 'Booking cancelled', 'Your booking was cancelled because the selected seats were given to another passenger. Please book again with different seats.', $2::jsonb)
           RETURNING id, user_id, type, title, body, data, created_at, is_read`,
          [ac.passengerId, JSON.stringify({ booking_id: ac.bookingId, trip_id: booking.trip_id })]
        );
        if (acn.rows[0]) emitNotificationToUser(acn.rows[0].user_id, acn.rows[0]);
      } catch (e) {
        logger.warn('Auto-cancel seat conflict notification failed:', e.message);
      }
    }

    // Post-transaction: notifications (non-critical, use pool not client)
    try {
      const pn = await pool.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'booking_accepted', 'Booking accepted!', 'Your booking has been approved by the driver. Have a safe ride!', $2::jsonb)
         RETURNING id, user_id, type, title, body, data, created_at, is_read`,
        [booking.passenger_id, JSON.stringify({ booking_id: bookingId, trip_id: booking.trip_id })]
      );
      if (pn.rows[0]) emitNotificationToUser(pn.rows[0].user_id, pn.rows[0]);
    } catch (e) {
      logger.warn('Booking accepted notification failed:', e.message);
    }

    try {
      const independent = booking.created_source === 'independent_driver' && booking.departure_time;
      if (independent) {
        await pool.query(
          `INSERT INTO pending_rate_notifications (booking_id, passenger_id, driver_id, send_after)
           VALUES ($1, $2, $3, $4::timestamp + INTERVAL '5 hours')`,
          [bookingId, booking.passenger_id, booking.driver_id, booking.departure_time]
        );
      } else {
        await pool.query(
          `INSERT INTO pending_rate_notifications (booking_id, passenger_id, driver_id, send_after)
           VALUES ($1, $2, $3, NOW() + INTERVAL '5 hours')`,
          [bookingId, booking.passenger_id, booking.driver_id]
        );
      }
    } catch (err) {
      if (err.code !== '42P01') {
        logger.warn('Pending rate notification insert failed:', err.message);
      }
    }

    emitTripUpdated(booking.trip_id, { bookingId, status: 'confirmed', reason: 'booking_confirmed' });

    ApiResponse.success({ status: 'confirmed' }, 'Booking approved').send(res);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
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
    ? 'AND b.created_at >= NOW() - make_interval(days => $4)'
    : '';
  const dataParams = days > 0
    ? [passengerId, limit, offset, days]
    : [passengerId, limit, offset];
  const countParams = days > 0
    ? [passengerId, days]
    : [passengerId];
  const countDateClause = days > 0
    ? 'AND b.created_at >= NOW() - make_interval(days => $2)'
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
      dataParams
    ),
    pool.query(
      `SELECT COUNT(*)::int AS total
       FROM bookings b
       WHERE b.passenger_id = $1
         ${countDateClause}`,
      countParams
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

const CANCEL_BEFORE_DEPARTURE_MINUTES = 60;
const PASSENGER_CANCEL_GRACE_MINUTES = 5;
const PASSENGER_CANCEL_WINDOW_DAYS = 30;
const PASSENGER_CANCEL_MAX = 8;
const PASSENGER_CANCEL_BLOCK_HOURS = 24;

/**
 * Cancel booking (Passenger only)
 * POST /api/bookings/:id/cancel
 * Body: { reason?: string }
 * Pending: always allowed. Confirmed: allowed until 2 min before departure (testing).
 */
const cancelBooking = asyncHandler(async (req, res) => {
  const bookingId = req.params.id;
  requireUuid(bookingId, 'booking ID');
  const passengerId = req.user.id;
  const reason = (req.body && req.body.reason != null) ? String(req.body.reason).trim() : null;

  try {
    const blockCheck = await pool.query(
      `SELECT cancel_blocked_until FROM users WHERE id = $1`,
      [passengerId]
    );
    if (blockCheck.rows[0]?.cancel_blocked_until && new Date(blockCheck.rows[0].cancel_blocked_until) > new Date()) {
      const until = new Date(blockCheck.rows[0].cancel_blocked_until);
      throw ApiError.badRequest(
        `Aapne bahut baar cancel kiya hai. ${until.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' })} tak cancel nahi kar sakte.`
      );
    }
  } catch (e) {
    if (e.statusCode) throw e;
    if (e.code !== '42703') logger.warn('Cancel block check failed:', e.message);
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const bookingResult = await client.query(
      `SELECT b.id, b.trip_id, b.passenger_id, b.status, b.seat_numbers, b.created_at AS booking_created_at,
              t.driver_id, t.departure_time, t.status AS trip_status
       FROM bookings b
       JOIN trips t ON b.trip_id = t.id
       WHERE b.id = $1
       FOR UPDATE OF b`,
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

    if (booking.trip_status === 'in_progress' || booking.trip_status === 'completed') {
      throw ApiError.badRequest('Ride has already started. Cancellation not allowed.');
    }

    const departureTime = new Date(booking.departure_time).getTime();
    const now = Date.now();

    if (now >= departureTime) {
      throw ApiError.badRequest('Ride has already started. Cancellation not allowed.');
    }

    const cutoffMs = CANCEL_BEFORE_DEPARTURE_MINUTES * 60 * 1000;
    if (booking.status === 'confirmed' && (departureTime - now) < cutoffMs) {
      const bookingCreatedMs = new Date(booking.booking_created_at).getTime();
      const graceMs = PASSENGER_CANCEL_GRACE_MINUTES * 60 * 1000;
      if ((now - bookingCreatedMs) > graceMs) {
        throw ApiError.badRequest(
          `Cancellation not allowed. Cancel at least ${CANCEL_BEFORE_DEPARTURE_MINUTES} minutes before departure.`
        );
      }
    }

    const seatCount = Array.isArray(booking.seat_numbers) ? booking.seat_numbers.length : 0;
    const wasConfirmed = booking.status === 'confirmed';

    await client.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(), cancellation_reason = $2
       WHERE id = $1 AND status != 'cancelled'`,
      [bookingId, reason || null]
    );

    if (seatCount > 0) {
      await client.query(
        'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
        [seatCount, booking.trip_id]
      );
    }

    await client.query('COMMIT');

    // Post-transaction notifications (non-critical)
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

    try {
      await pool.query('DELETE FROM pending_rate_notifications WHERE booking_id = $1', [bookingId]);
    } catch (e) {
      if (e.code !== '42P01') logger.warn('Rate notification cleanup failed:', e.message);
    }

    emitTripUpdated(booking.trip_id, { bookingId, status: 'cancelled', reason: 'passenger_cancelled' });

    if (wasConfirmed) {
      try {
        const countRes = await pool.query(
          `SELECT COUNT(*)::int AS cnt FROM bookings
           WHERE passenger_id = $1 AND status = 'cancelled'
             AND cancellation_reason NOT LIKE 'auto-%'
             AND cancelled_at > NOW() - ($2::int * INTERVAL '1 day')`,
          [passengerId, PASSENGER_CANCEL_WINDOW_DAYS]
        );
        const recentCancels = countRes.rows[0]?.cnt || 0;
        if (recentCancels >= PASSENGER_CANCEL_MAX) {
          await pool.query(
            `UPDATE users SET cancel_blocked_until = NOW() + ($2::int * INTERVAL '1 hour'), cancel_count = $3
             WHERE id = $1`,
            [passengerId, PASSENGER_CANCEL_BLOCK_HOURS, recentCancels]
          );
          logger.info(`Passenger ${passengerId} cancel-blocked for ${PASSENGER_CANCEL_BLOCK_HOURS}h (${recentCancels} cancels in ${PASSENGER_CANCEL_WINDOW_DAYS}d)`);
        }
      } catch (e) {
        if (e.code !== '42703') logger.warn('Cancel tracking failed:', e.message);
      }
    }

    if (wasConfirmed) {
      try {
        const rn = await pool.query(
          `INSERT INTO notifications (user_id, type, title, body, data)
           VALUES ($1, 'rate_ride', 'Rate your passenger', 'Passenger ne ride cancel ki. Apna experience rate karein.', $2::jsonb)
           RETURNING id, user_id, type, title, body, data, created_at, is_read`,
          [booking.driver_id, JSON.stringify({ booking_id: bookingId, trip_id: booking.trip_id, rate_only: 'passenger' })]
        );
        if (rn.rows[0]) emitNotificationToUser(rn.rows[0].user_id, rn.rows[0]);
      } catch (e) {
        logger.warn('Cancel rate notification (driver) failed:', e.message);
      }
    }

    ApiResponse.success({ status: 'cancelled' }, 'Booking cancelled').send(res);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

module.exports = {
  createBooking,
  respondToBooking,
  getMyBookings,
  cancelBooking
};
