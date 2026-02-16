# LuhaRide Mobile – Architecture

## Principles

### 1. Data layer (models)
- **Immutable DTOs**: `fromJson` for API → model; `toJson` when sending.
- **Consistency**: Prefer `copyWith`, `==`, `hashCode` for key models (e.g. `NotificationModel`, `TripModel`).
- **Single source of truth**: One model per API entity; no duplicate shapes.

### 2. API layer
- **ApiService**: Singleton Dio client; base URL from `EnvConfig`; interceptors for auth token and logging.
- **ApiConstants**: All path builders (e.g. `userRatingSummary(userId)`, `rateBooking(bookingId)`) in one place.
- **Services**: One per domain (e.g. `ReviewService`, `NotificationService`); call ApiService + ApiConstants; return typed maps or model lists.

### 3. State & UI
- **Provider**: `AuthProvider` for auth state; other providers as needed.
- **Screens**: Use services and providers; no direct Dio in widgets.
- **Pagination**: List screens use `page`/`limit` and “Load more” (e.g. ratings).

### 4. Scalability
- **Pagination**: Reviews and user reviews load in pages (e.g. 20) to keep payloads small.
- **Stateless**: No heavy local state; server is source of truth for bookings, trips, ratings.
- **Constants**: API base URL and timeouts in config; easy to point to staging/prod.

## Structure

```
lib/
  core/         – api_constants, config (env)
  models/       – DTOs (fromJson, toJson, copyWith where needed)
  providers/    – AuthProvider, etc.
  screens/      – UI by feature (auth, home, trips, profile, notifications)
  services/     – API clients (ReviewService, TripService, NotificationService, …)
  widgets/      – Reusable (e.g. RateRideDialog)
```

## OOP

- **Models**: Value objects; factory constructors and optional equality.
- **Services**: Encapsulate API calls; single responsibility per domain.
- **Providers**: Extend `ChangeNotifier`; expose minimal state and methods.
