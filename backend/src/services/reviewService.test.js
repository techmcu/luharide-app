/**
 * Review/rating business logic — SOP BL-029→033, P-042→046
 * All repositories and DB are mocked — no real database connection.
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
jest.mock('../repositories/rideRatingsRepository');
jest.mock('../repositories/bookingRepository');

const { pool } = require('../config/database');
const rideRatingsRepository = require('../repositories/rideRatingsRepository');
const bookingRepository = require('../repositories/bookingRepository');
const { submitRating, getReviewsForUser, getRatingSummary } = require('./reviewService');

const DRIVER_ID = 'b0000000-0000-0000-0000-000000000001';
const PASS_ID   = 'c0000000-0000-0000-0000-000000000001';
const BOOK_ID   = 'd0000000-0000-0000-0000-000000000001';

function makeBooking(overrides = {}) {
  return {
    id: BOOK_ID,
    passenger_id: PASS_ID,
    driver_id: DRIVER_ID,
    status: 'completed',
    from_location: 'Dehradun',
    to_location: 'Purola',
    departure_time: new Date().toISOString(),
    cancellation_reason: null,
    ...overrides,
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  rideRatingsRepository.ensureTable.mockResolvedValue();
  rideRatingsRepository.findByBookingAndRole.mockResolvedValue(null);
  rideRatingsRepository.create.mockResolvedValue({ id: 'r1' });
  pool.query.mockResolvedValue({ rows: [] });
});

// ── SOP P-042: Valid rating 1-5 ───────────────────────────────────────────
describe('submitRating — valid cases', () => {
  it('accepts rating within 1-5 range', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(makeBooking());

    const result = await submitRating(BOOK_ID, PASS_ID, { rating: 4, comment: '' });
    expect(result.rated_user_id).toBe(DRIVER_ID);
    expect(rideRatingsRepository.create).toHaveBeenCalled();
  });

  // ── SOP P-043: Rating with comment ──────────────────────────────────────
  it('accepts rating with comment', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(makeBooking());

    await submitRating(BOOK_ID, PASS_ID, { rating: 5, comment: 'Great ride' });

    const createCall = rideRatingsRepository.create.mock.calls[0][0];
    expect(createCall.comment).toBe('Great ride');
  });

  // ── Passenger rates driver ──────────────────────────────────────────────
  it('sets from_role=passenger when passenger rates', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(makeBooking());

    await submitRating(BOOK_ID, PASS_ID, { rating: 3 });

    const createCall = rideRatingsRepository.create.mock.calls[0][0];
    expect(createCall.fromRole).toBe('passenger');
    expect(createCall.ratedUserId).toBe(DRIVER_ID);
  });

  // ── SOP D-033: Driver rates passenger ───────────────────────────────────
  it('sets from_role=driver when driver rates', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(makeBooking());

    await submitRating(BOOK_ID, DRIVER_ID, { rating: 2 });

    const createCall = rideRatingsRepository.create.mock.calls[0][0];
    expect(createCall.fromRole).toBe('driver');
    expect(createCall.ratedUserId).toBe(PASS_ID);
  });
});

// ── Validation errors ─────────────────────────────────────────────────────
describe('submitRating — validation', () => {
  it('rejects rating=0', async () => {
    await expect(submitRating(BOOK_ID, PASS_ID, { rating: 0 })).rejects.toThrow(/1 to 5/);
  });

  it('rejects rating=6', async () => {
    await expect(submitRating(BOOK_ID, PASS_ID, { rating: 6 })).rejects.toThrow(/1 to 5/);
  });

  it('rejects non-integer rating', async () => {
    await expect(submitRating(BOOK_ID, PASS_ID, { rating: 3.5 })).rejects.toThrow(/1 to 5/);
  });

  it('rejects comment exceeding max words', async () => {
    const longComment = Array(25).fill('word').join(' ');
    await expect(submitRating(BOOK_ID, PASS_ID, { rating: 3, comment: longComment })).rejects.toThrow(/words/);
  });

  it('rejects when booking not found', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(null);
    await expect(submitRating(BOOK_ID, PASS_ID, { rating: 3 })).rejects.toThrow(/not found/);
  });

  it('rejects rating for pending booking', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(makeBooking({ status: 'pending' }));
    await expect(submitRating(BOOK_ID, PASS_ID, { rating: 3 })).rejects.toThrow(/completed or cancelled/);
  });

  it('rejects unrelated user', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(makeBooking());
    await expect(submitRating(BOOK_ID, 'x0000000-0000-0000-0000-000000000099', { rating: 3 }))
      .rejects.toThrow(/only rate your own/);
  });
});

// ── SOP BL-029→033: Cancel rating rules ───────────────────────────────────
describe('submitRating — cancelled booking rules', () => {
  // BL-029: Cancelled by driver → passenger CAN rate
  it('allows passenger to rate when driver cancelled', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(
      makeBooking({ status: 'cancelled', cancellation_reason: 'Driver cancelled the trip' })
    );

    const result = await submitRating(BOOK_ID, PASS_ID, { rating: 1 });
    expect(result.rated_user_id).toBe(DRIVER_ID);
  });

  // BL-031: Cancelled by driver → driver CANNOT rate
  it('blocks driver from rating when they cancelled', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(
      makeBooking({ status: 'cancelled', cancellation_reason: 'Driver cancelled the trip' })
    );

    await expect(submitRating(BOOK_ID, DRIVER_ID, { rating: 3 }))
      .rejects.toThrow(/You cancelled the ride/);
  });

  // BL-030: Cancelled by passenger → driver CAN rate
  it('allows driver to rate when passenger cancelled', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(
      makeBooking({ status: 'cancelled', cancellation_reason: 'plans changed' })
    );

    const result = await submitRating(BOOK_ID, DRIVER_ID, { rating: 2 });
    expect(result.rated_user_id).toBe(PASS_ID);
  });

  // BL-032: Cancelled by passenger → passenger CANNOT rate
  it('blocks passenger from rating when they cancelled', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(
      makeBooking({ status: 'cancelled', cancellation_reason: 'plans changed' })
    );

    await expect(submitRating(BOOK_ID, PASS_ID, { rating: 4 }))
      .rejects.toThrow(/You cancelled the booking/);
  });

  // BL-033: Auto-cancelled → nobody can rate
  it('blocks rating for auto-cancelled booking', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(
      makeBooking({ status: 'cancelled', cancellation_reason: 'auto-expired' })
    );

    await expect(submitRating(BOOK_ID, PASS_ID, { rating: 3 }))
      .rejects.toThrow(/Auto-cancelled/);
  });

  // Admin-cancelled → nobody can rate
  it('blocks rating for admin-cancelled booking', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(
      makeBooking({ status: 'cancelled', cancellation_reason: 'Cancelled by platform admin' })
    );

    await expect(submitRating(BOOK_ID, PASS_ID, { rating: 3 }))
      .rejects.toThrow(/Admin-cancelled/);
  });
});

// ── Duplicate and auto-rating ─────────────────────────────────────────────
describe('submitRating — duplicates', () => {
  it('rejects duplicate rating', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(makeBooking());
    rideRatingsRepository.findByBookingAndRole.mockResolvedValue({
      id: 'r1', rating: 4, comment: 'Good',
    });

    await expect(submitRating(BOOK_ID, PASS_ID, { rating: 5 }))
      .rejects.toThrow(/already rated/);
  });

  it('replaces auto-rating with real rating', async () => {
    bookingRepository.getBookingWithTripForRating.mockResolvedValue(makeBooking());
    rideRatingsRepository.findByBookingAndRole.mockResolvedValue({
      id: 'r1', rating: 1, comment: 'Auto-rating: Passenger cancelled',
    });

    await submitRating(BOOK_ID, PASS_ID, { rating: 4, comment: 'Good' });

    expect(pool.query).toHaveBeenCalledWith(
      expect.stringContaining('UPDATE ride_ratings'),
      expect.arrayContaining([4, 'Good'])
    );
  });
});

// ── SOP P-044: Get reviews for user ───────────────────────────────────────
describe('getReviewsForUser', () => {
  it('returns paginated reviews', async () => {
    rideRatingsRepository.countByRatedUserId.mockResolvedValue(15);
    rideRatingsRepository.listByRatedUserId.mockResolvedValue([
      { id: 'r1', rating: 5 }, { id: 'r2', rating: 3 },
    ]);

    const result = await getReviewsForUser(DRIVER_ID, 1, 10);

    expect(result.total).toBe(15);
    expect(result.reviews).toHaveLength(2);
    expect(result.page).toBe(1);
  });
});

// ── SOP P-045: Rating summary ─────────────────────────────────────────────
describe('getRatingSummary', () => {
  it('returns average and total', async () => {
    rideRatingsRepository.getSummaryByUserId.mockResolvedValue({
      total_ratings: 10, average_rating: 4.23456, latest_review_at: new Date(),
    });

    const result = await getRatingSummary(DRIVER_ID);

    expect(result.total_ratings).toBe(10);
    expect(result.average_rating).toBe(4.23);
    expect(result.user_id).toBe(DRIVER_ID);
  });
});
