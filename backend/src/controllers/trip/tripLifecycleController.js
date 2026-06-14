const { pool } = require('../../config/database');
const ApiError = require('../../utils/ApiError');
const ApiResponse = require('../../utils/ApiResponse');
const asyncHandler = require('../../utils/asyncHandler');
const logger = require('../../config/logger');
const { emitNotificationToUser, emitTripUpdated } = require('../../socket/realtimeEmitter');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function requireUuid(id) {
  if (!id || !UUID_RE.test(id)) throw ApiError.badRequest('Invalid trip ID');
}

/**
 * Start trip (Driver only) - scheduled -> in_progress
 * PUT /api/trips/:id/start
 */
const startTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;

  let cancelledBookings = [];

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tripResult = await client.query(
      'SELECT id, status, departure_time, created_source FROM trips WHERE id = $1 AND driver_id = $2 FOR UPDATE',
      [tripId, driverId]
    );

    if (tripResult.rows.length === 0) {
      await client.query('ROLLBACK');
      throw ApiError.notFound('Trip not found');
    }

    const trip = tripResult.rows[0];
    if (trip.status !== 'scheduled') {
      await client.query('ROLLBACK');
      throw ApiError.badRequest(`Cannot start trip. Current status: ${trip.status}. Only scheduled trips can be started.`);
    }

    if (trip.created_source === 'independent_driver' && trip.departure_time && new Date(trip.departure_time).getTime() > Date.now()) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Independent rides auto-start at departure time. Manual start is not available.');
    }

    const pending = await client.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
         cancellation_reason = 'auto-expired-trip-started'
       WHERE trip_id = $1 AND status = 'pending'
       RETURNING id, passenger_id, seat_numbers`,
      [tripId]
    );
    cancelledBookings = pending.rows;

    let restoredSeats = 0;
    for (const row of cancelledBookings) {
      restoredSeats += Array.isArray(row.seat_numbers) ? row.seat_numbers.length : 0;
    }
    if (restoredSeats > 0) {
      await client.query(
        'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
        [restoredSeats, tripId]
      );
    }

    try {
      await client.query(
        `UPDATE trips SET status = 'in_progress', started_at = COALESCE(started_at, NOW()) WHERE id = $1`,
        [tripId]
      );
    } catch (err) {
      if (err.code === '42703') {
        await client.query("UPDATE trips SET status = 'in_progress' WHERE id = $1", [tripId]);
      } else {
        throw err;
      }
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  for (const row of cancelledBookings) {
    try {
      const dataJson = JSON.stringify({ booking_id: row.id, trip_id: tripId });
      const n = await pool.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'booking_auto_cancelled',
           'Booking not confirmed',
           'Your booking was auto-cancelled because the driver started the ride without confirming your request.',
           $2::jsonb)
         RETURNING id, user_id, type, title, body, data, created_at, is_read`,
        [row.passenger_id, dataJson]
      );
      if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
    } catch (_) {}
  }
  if (cancelledBookings.length > 0) {
    emitTripUpdated(tripId, { reason: 'trip_started_pending_cancelled' });
  }

  ApiResponse.success(
    { status: 'in_progress', pendingBookingsCancelled: cancelledBookings.length },
    cancelledBookings.length > 0
      ? `Ride started. ${cancelledBookings.length} pending booking(s) were auto-cancelled.`
      : 'Ride started'
  ).send(res);
});

/**
 * Complete trip (Driver only) - in_progress -> completed
 * PUT /api/trips/:id/complete
 */
const completeTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tripResult = await client.query(
      'SELECT id, status, departure_time FROM trips WHERE id = $1 AND driver_id = $2 FOR UPDATE',
      [tripId, driverId]
    );

    if (tripResult.rows.length === 0) {
      await client.query('ROLLBACK');
      throw ApiError.notFound('Trip not found');
    }

    const trip = tripResult.rows[0];
    if (trip.status !== 'in_progress') {
      await client.query('ROLLBACK');
      throw ApiError.badRequest(
        `Cannot complete trip. Current status: ${trip.status}. Only in-progress trips can be completed.`
      );
    }

    if (trip.departure_time && new Date(trip.departure_time).getTime() > Date.now()) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Cannot complete ride before departure time.');
    }

    await client.query(
      "UPDATE trips SET status = 'completed' WHERE id = $1",
      [tripId]
    );

    const completedBookings = await client.query(
      `UPDATE bookings SET status = 'completed'
       WHERE trip_id = $1 AND status = 'confirmed'
       RETURNING id, passenger_id`,
      [tripId]
    );

    const pendingOnComplete = await client.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(),
         cancellation_reason = 'auto-expired-trip-completed'
       WHERE trip_id = $1 AND status = 'pending'
       RETURNING id, passenger_id, seat_numbers`,
      [tripId]
    );

    let restoredSeats = 0;
    for (const row of pendingOnComplete.rows) {
      restoredSeats += Array.isArray(row.seat_numbers) ? row.seat_numbers.length : 0;
    }
    if (restoredSeats > 0) {
      await client.query(
        'UPDATE trips SET available_seats = available_seats + $1 WHERE id = $2',
        [restoredSeats, tripId]
      );
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  for (const bk of completedBookings.rows) {
    try {
      const n = await pool.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'trip_completed',
           'Happy Journey!',
           'We hope you had a great travel experience with LuhaRide!',
           $2::jsonb)
         RETURNING id, user_id, type, title, body, data, created_at, is_read`,
        [bk.passenger_id, JSON.stringify({ booking_id: bk.id, trip_id: tripId })]
      );
      if (n.rows[0]) emitNotificationToUser(n.rows[0].user_id, n.rows[0]);
    } catch (_) {}
  }

  emitTripUpdated(tripId, { status: 'completed', reason: 'driver_completed' });

  ApiResponse.success(
    { status: 'completed' },
    'Ride completed'
  ).send(res);
});

const DRIVER_CANCEL_WINDOW_DAYS = 30;
const DRIVER_CANCEL_MAX = 5;
const DRIVER_CANCEL_BLOCK_HOURS = 48;
const DRIVER_PERM_BLOCK_WINDOW_DAYS = 90;
const DRIVER_PERM_BLOCK_MAX = 12;

const cancelTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;

  try {
    const blockCheck = await pool.query(
      `SELECT cancel_blocked_until FROM users WHERE id = $1`,
      [driverId]
    );
    if (blockCheck.rows[0]?.cancel_blocked_until && new Date(blockCheck.rows[0].cancel_blocked_until) > new Date()) {
      const until = new Date(blockCheck.rows[0].cancel_blocked_until);
      throw ApiError.badRequest(
        'You have cancelled too many rides recently. Please try again later.'
      );
    }
  } catch (e) {
    if (e.statusCode) throw e;
    if (e.code !== '42703') logger.warn('Cancel block check failed:', e.message);
  }

  const client = await pool.connect();
  let notifyPassengers = [];
  let cancelledBookingIds = [];
  let confirmedPassengerIds = [];
  try {
    await client.query('BEGIN');

    const tripResult = await client.query(
      'SELECT id, status, departure_time, driver_id, created_at FROM trips WHERE id = $1 AND driver_id = $2 FOR UPDATE',
      [tripId, driverId]
    );

    if (tripResult.rows.length === 0) {
      await client.query('ROLLBACK');
      throw ApiError.notFound('Trip not found');
    }

    const trip = tripResult.rows[0];
    if (trip.status === 'cancelled' || trip.status === 'completed') {
      await client.query('ROLLBACK');
      throw ApiError.badRequest(`Trip is already ${trip.status}. Cannot cancel.`);
    }
    if (trip.status === 'in_progress') {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Ride has already started. Cancellation not allowed.');
    }

    const departureTimeMs = new Date(trip.departure_time).getTime();
    const now = Date.now();
    if (now >= departureTimeMs) {
      await client.query('ROLLBACK');
      throw ApiError.badRequest('Ride start time has passed. Cancellation not allowed.');
    }

    const allActiveBookings = await client.query(
      `SELECT id, passenger_id, seat_numbers, status FROM bookings WHERE trip_id = $1 AND status IN ('pending', 'confirmed')`,
      [tripId]
    );
    const confirmedRows = allActiveBookings.rows.filter(r => r.status === 'confirmed');
    cancelledBookingIds = confirmedRows.map(r => r.id);
    confirmedPassengerIds = confirmedRows.map(r => ({ passenger_id: r.passenger_id, booking_id: r.id }));

    await client.query(
      `UPDATE bookings SET status = 'cancelled', cancelled_at = NOW(), cancellation_reason = 'Driver cancelled the trip' WHERE trip_id = $1 AND status IN ('pending', 'confirmed')`,
      [tripId]
    );

    let seatsToRelease = 0;
    for (const row of allActiveBookings.rows) {
      const seats = Array.isArray(row.seat_numbers) ? row.seat_numbers : [];
      seatsToRelease += seats.length;
    }

    if (seatsToRelease > 0) {
      await client.query(
        `UPDATE trips SET available_seats = available_seats + $1, status = 'cancelled', cancelled_by = 'driver' WHERE id = $2`,
        [seatsToRelease, tripId]
      );
    } else {
      await client.query(
        "UPDATE trips SET status = 'cancelled', cancelled_by = 'driver' WHERE id = $1",
        [tripId]
      );
    }

    if (allActiveBookings.rows.length > 0) {
      const placeholders = allActiveBookings.rows
        .map((_, i) => `($${i + 1}, 'trip_cancelled', 'Ride cancelled', 'The driver cancelled this ride. You are not charged.')`)
        .join(', ');
      const flatParams = allActiveBookings.rows.map(r => r.passenger_id);
      try {
        const nIns = await client.query(
          `INSERT INTO notifications (user_id, type, title, body) VALUES ${placeholders}
           RETURNING id, user_id, type, title, body, created_at, is_read`,
          flatParams
        );
        notifyPassengers = nIns.rows;
      } catch (e) {
        logger.warn('Batch passenger cancel notification failed:', e.message);
      }
    }

    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  if (cancelledBookingIds.length > 0) {
    try {
      await pool.query('DELETE FROM pending_rate_notifications WHERE booking_id = ANY($1::uuid[])', [cancelledBookingIds]);
    } catch (e) {
      if (e.code !== '42P01') logger.warn('Rate notification cleanup failed:', e.message);
    }
  }

  for (const row of notifyPassengers) {
    emitNotificationToUser(row.user_id, row);
  }

  let driverNameForNotif = '';
  try {
    const dr = await pool.query('SELECT name FROM users WHERE id = $1', [driverId]);
    driverNameForNotif = dr.rows[0]?.name || 'Driver';
  } catch (_) {}

  for (const { passenger_id, booking_id } of confirmedPassengerIds) {
    try {
      await pool.query(
        `INSERT INTO ride_ratings (booking_id, from_user_id, rated_user_id, from_role, rating, comment)
         VALUES ($1, $2, $3, 'passenger', 1, 'Auto-rating: Driver cancelled the ride.')
         ON CONFLICT DO NOTHING`,
        [booking_id, passenger_id, driverId]
      );
    } catch (e) {
      if (e.code !== '42P01') logger.warn('Auto 1-star for driver failed:', e.message);
    }
    try {
      const rateData = JSON.stringify({
        booking_id, trip_id: tripId, rate_only: 'driver',
        target_name: driverNameForNotif,
      });
      const rn = await pool.query(
        `INSERT INTO notifications (user_id, type, title, body, data)
         VALUES ($1, 'rate_ride', 'Rate your driver', $2, $3::jsonb)
         RETURNING id, user_id, type, title, body, data, created_at, is_read`,
        [passenger_id, `Rate ${driverNameForNotif} — cancelled your ride.`, rateData]
      );
      if (rn.rows[0]) emitNotificationToUser(rn.rows[0].user_id, rn.rows[0]);
    } catch (e) {
      logger.warn('Cancel rate notification (passenger) failed:', e.message);
    }
  }

  emitTripUpdated(tripId, { reason: 'driver_cancelled_trip' });

  logger.info(`Trip cancelled: ${tripId} by driver ${driverId}`);

  try {
    const countRes = await pool.query(
      `SELECT
         (SELECT COUNT(*)::int FROM trips WHERE driver_id = $1 AND status = 'cancelled' AND COALESCE(cancelled_by, 'driver') = 'driver' AND updated_at > NOW() - ($2::int * INTERVAL '1 day')) AS recent,
         (SELECT COUNT(*)::int FROM trips WHERE driver_id = $1 AND status = 'cancelled' AND COALESCE(cancelled_by, 'driver') = 'driver' AND updated_at > NOW() - ($3::int * INTERVAL '1 day')) AS long_term`,
      [driverId, DRIVER_CANCEL_WINDOW_DAYS, DRIVER_PERM_BLOCK_WINDOW_DAYS]
    );
    const recent = countRes.rows[0]?.recent || 0;
    const longTerm = countRes.rows[0]?.long_term || 0;
    if (longTerm >= DRIVER_PERM_BLOCK_MAX) {
      await pool.query(
        `UPDATE users SET cancel_blocked_until = '2099-12-31'::timestamp, cancel_count = $2
         WHERE id = $1`,
        [driverId, longTerm]
      );
      logger.info(`Driver ${driverId} PERMANENTLY blocked (${longTerm} cancels in ${DRIVER_PERM_BLOCK_WINDOW_DAYS}d)`);
    } else if (recent >= DRIVER_CANCEL_MAX) {
      await pool.query(
        `UPDATE users SET cancel_blocked_until = NOW() + ($2::int * INTERVAL '1 hour'), cancel_count = $3
         WHERE id = $1`,
        [driverId, DRIVER_CANCEL_BLOCK_HOURS, recent]
      );
      logger.info(`Driver ${driverId} temp-blocked ${DRIVER_CANCEL_BLOCK_HOURS}h (${recent} cancels in ${DRIVER_CANCEL_WINDOW_DAYS}d)`);
    }
  } catch (e) {
    if (e.code !== '42703') logger.warn('Cancel tracking failed:', e.message);
  }

  // Create+cancel abuse tracking: flag drivers who repeatedly create and cancel rides
  const CREATE_CANCEL_DAILY_LIMIT = 5;
  const CREATE_CANCEL_MONTH_STRIKE_LIMIT = 3;
  const CREATE_CANCEL_BLOCK_HOURS = 48;
  try {
    const dailyCancels = await pool.query(
      `SELECT COUNT(*)::int AS cnt FROM trips
       WHERE driver_id = $1 AND status = 'cancelled' AND COALESCE(cancelled_by, 'driver') = 'driver'
         AND created_source = 'independent_driver'
         AND updated_at >= CURRENT_DATE::timestamp
         AND updated_at < (CURRENT_DATE + 1)::timestamp`,
      [driverId]
    );
    const todayCancels = dailyCancels.rows[0]?.cnt || 0;

    if (todayCancels >= CREATE_CANCEL_DAILY_LIMIT) {
      const monthKey = new Date().toISOString().slice(0, 7);
      let monthStrikes = 0;
      try {
        const strikeRes = await pool.query(
          `SELECT COUNT(*)::int AS cnt FROM driver_abuse_flags
           WHERE user_id = $1 AND flag_type = 'create_cancel_abuse' AND month_window = $2`,
          [driverId, monthKey]
        );
        monthStrikes = strikeRes.rows[0]?.cnt || 0;
      } catch (e2) {
        if (e2.code !== '42P01') logger.warn('Abuse flag check failed:', e2.message);
      }

      const blockedUntil = monthStrikes + 1 >= CREATE_CANCEL_MONTH_STRIKE_LIMIT
        ? new Date(Date.now() + CREATE_CANCEL_BLOCK_HOURS * 60 * 60 * 1000)
        : null;

      try {
        await pool.query(
          `INSERT INTO driver_abuse_flags (user_id, flag_type, reason, month_window, violation_count, blocked_until)
           VALUES ($1, 'create_cancel_abuse', $2, $3, $4, $5)`,
          [
            driverId,
            `Driver cancelled ${todayCancels} rides today (limit: ${CREATE_CANCEL_DAILY_LIMIT}). Strike ${monthStrikes + 1}/${CREATE_CANCEL_MONTH_STRIKE_LIMIT} this month.`,
            monthKey,
            todayCancels,
            blockedUntil,
          ]
        );
      } catch (e3) {
        if (e3.code !== '42P01') logger.warn('Abuse flag insert failed:', e3.message);
      }

      if (blockedUntil) {
        await pool.query(
          `UPDATE users SET cancel_blocked_until = $2 WHERE id = $1`,
          [driverId, blockedUntil.toISOString()]
        );
        logger.info(`Driver ${driverId} blocked ${CREATE_CANCEL_BLOCK_HOURS}h for create+cancel abuse (${monthStrikes + 1} strikes this month)`);

        try {
          const wn = await pool.query(
            `INSERT INTO notifications (user_id, type, title, body, data)
             VALUES ($1, 'account_warning',
               'Account temporarily restricted',
               'Your account has been temporarily restricted for 48 hours due to repeated ride cancellations. Please create rides only when you intend to complete them.',
               $2::jsonb)
             RETURNING id, user_id, type, title, body, data, created_at, is_read`,
            [driverId, JSON.stringify({ blocked_until: blockedUntil.toISOString(), reason: 'create_cancel_abuse' })]
          );
          if (wn.rows[0]) emitNotificationToUser(wn.rows[0].user_id, wn.rows[0]);
        } catch (_) {}
      } else if (todayCancels >= CREATE_CANCEL_DAILY_LIMIT) {
        try {
          const wn = await pool.query(
            `INSERT INTO notifications (user_id, type, title, body, data)
             VALUES ($1, 'account_warning',
               'Warning: Too many cancellations',
               'You have cancelled too many rides today. Repeated abuse may lead to temporary account restrictions.',
               '{"reason":"create_cancel_warning"}'::jsonb)
             RETURNING id, user_id, type, title, body, data, created_at, is_read`,
            [driverId]
          );
          if (wn.rows[0]) emitNotificationToUser(wn.rows[0].user_id, wn.rows[0]);
        } catch (_) {}
      }
    }
  } catch (e) {
    if (e.code !== '42P01' && e.code !== '42703') logger.warn('Create+cancel abuse tracking failed:', e.message);
  }

  ApiResponse.success(
    { status: 'cancelled' },
    'Trip cancelled. Passengers have been notified.'
  ).send(res);
});

/**
 * Delete trip (Driver only)
 * Allowed ONLY within 1 hour of creation AND no confirmed/pending bookings.
 * After 1 hour the ride is permanent - use cancel instead.
 * DELETE /api/trips/:id
 */
const DELETE_WINDOW_HOURS = 1;

const deleteTrip = asyncHandler(async (req, res) => {
  const { id: tripId } = req.params;
  requireUuid(tripId);
  const driverId = req.user.id;
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const tripResult = await client.query(
      'SELECT id, created_at FROM trips WHERE id = $1 AND driver_id = $2 FOR UPDATE',
      [tripId, driverId]
    );

    if (tripResult.rows.length === 0) {
      throw ApiError.notFound('Trip not found');
    }

    const createdAt = new Date(tripResult.rows[0].created_at);
    const hoursSinceCreation = (Date.now() - createdAt.getTime()) / (1000 * 60 * 60);
    if (hoursSinceCreation > DELETE_WINDOW_HOURS) {
      throw ApiError.badRequest(
        `Ride can only be deleted within ${DELETE_WINDOW_HOURS} hour(s) of creation. Use cancel instead.`
      );
    }

    const bookingsCheck = await client.query(
      `SELECT status FROM bookings
       WHERE trip_id = $1 AND status IN ('confirmed', 'pending')`,
      [tripId]
    );

    if (bookingsCheck.rows.length > 0) {
      const confirmedCount = bookingsCheck.rows.filter(r => r.status === 'confirmed').length;
      const pendingCount = bookingsCheck.rows.filter(r => r.status === 'pending').length;
      const msg = confirmedCount > 0
        ? `Cannot delete ride. ${confirmedCount} seat(s) are already booked. Passengers would be affected.`
        : `Cannot delete ride. ${pendingCount} booking request(s) are pending. Please accept or reject them first.`;
      throw ApiError.badRequest(msg);
    }

    await client.query('DELETE FROM bookings WHERE trip_id = $1', [tripId]);
    await client.query('DELETE FROM trips WHERE id = $1', [tripId]);

    await client.query('COMMIT');

    logger.info(`Trip deleted: ${tripId} by driver ${driverId}`);

    ApiResponse.success({ deleted: true }, 'Ride deleted successfully').send(res);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
});

module.exports = {
  startTrip,
  completeTrip,
  cancelTrip,
  deleteTrip,
};
