# Ratings & reviews (LuhaRide mobile)

This is a **first-class product feature**: submit ratings after rides, show averages and review lists on profiles / trip details.

## Mobile (implemented)

- **`ReviewService`**: submit rating (`ApiConstants.rateBooking`), load user review bundle + summary, cache + fingerprint after login.
- **`ReviewCacheStore`**: local cache invalidation when ratings change.
- **UI**: `RateRideDialog`, `RatingsScreen`, `UserReviewsScreen`; trip / profile entry points use real API data (empty state when no reviews yet).
- **No fake fixed score** (e.g. hardcoded 4.8) — UI reflects server.

## Backend / product (optional extras)

- **Email / cron nudges** (“rate after trip”) are **marketing/ops**, not required for in-app rating to work.
- Keep API contracts for `rateBooking` / review listing aligned with `ApiConstants`.

## Historical note

Older `lib/RATING_FEATURE_PENDING.md` described pre-API placeholder text; it has been **removed** to avoid confusing new devs.
