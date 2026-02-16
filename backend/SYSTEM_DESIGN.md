# LuhaRide – System Design & Architecture

## Principles

### 1. Separation of concerns
- **Controllers**: HTTP only – parse request, call service, send response (thin).
- **Services**: Business logic – validation, rules, orchestration; no DB access.
- **Repositories**: Data access – queries, table creation; no business rules.
- **Constants**: Pagination limits, validation rules (e.g. max comment words) in one place.

### 2. Data structures & API contract
- **Response shape**: All API responses use `ApiResponse`: `{ success, message, data }`.
- **Pagination**: `page`, `limit`, `total`, `has_more` for list endpoints; limits in `constants/pagination.js` (default 20, max 50).
- **Ids**: UUIDs for bookings, trips, users, notifications, ride_ratings.

### 3. Scalability
- **Stateless API**: No server-side session; JWT for auth – ready for horizontal scaling.
- **DB**: Connection pool (max 20); indexed queries on `ride_ratings(rated_user_id)`, `ride_ratings(booking_id)`, `notifications(user_id)`.
- **Pagination**: All list APIs support `page` and `limit` to avoid large payloads.
- **Rate notifications**: Background job (1-min interval) processes `pending_rate_notifications`; can be moved to a queue (e.g. Bull/Redis) later.

### 4. OOP & single responsibility
- **ApiError**: Central error class with static factory methods (badRequest, notFound, etc.).
- **ApiResponse**: Central response class; `.send(res)` for consistent JSON.
- **Repositories**: One per aggregate (e.g. `rideRatingsRepository`, `bookingRepository`); encapsulate SQL.
- **Services**: One per domain area (e.g. `reviewService`); use repositories, throw ApiError.

### 5. Naming & types
- **Backend**: camelCase for JS; DB columns snake_case; API JSON snake_case for consistency with mobile.
- **Mobile**: Dart classes with `fromJson` / `toJson`; API client uses same base URL and interceptors.

## Directory layout (backend)

```
src/
  config/       – database, logger, env
  constants/    – pagination, validation (business rules)
  controllers/  – HTTP handlers (thin)
  middleware/   – auth, validation, errorHandler
  repositories/ – DB access per entity
  services/     – business logic
  jobs/         – scheduled tasks (e.g. rate notifications)
  routes/       – Express routers
  utils/        – ApiError, ApiResponse, asyncHandler
```

## Data flow (example: submit rating)

1. **Route** → `POST /api/bookings/:id/rate` → `reviewController.submitRating`
2. **Controller** → extracts `id`, `req.user.id`, `req.body` → `reviewService.submitRating(bookingId, userId, { rating, comment })`
3. **Service** → validates rating 1–5 and comment words → `bookingRepository.getBookingWithTripForRating(bookingId)` → resolves role → `rideRatingsRepository.ensureTable()` → `findByBookingAndRole` → `create(...)`
4. **Controller** → `ApiResponse.created(payload).send(res)`

## Scaling checklist

- [x] Stateless API
- [x] Pagination on list endpoints
- [x] Indexes on hot query columns
- [x] Env-based config (DB, JWT)
- [ ] Optional: Redis for rate-notification queue
- [ ] Optional: Read replica for heavy read endpoints
