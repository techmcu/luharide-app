# LuhaRide Mobile – Architecture

## Principles

### 1. Data layer (models)
- **Immutable DTOs**: `fromJson` for API → model; `toJson` when sending.
- **Consistency**: Prefer `copyWith`, `==`, `hashCode` for key models (e.g. `NotificationModel`, `TripModel`).
- **Single source of truth**: One model per API entity; no duplicate shapes.

### 2. API layer
- **ApiService**: Singleton Dio client; full URLs via `buildApiUrl` + `EnvConfig`; interceptors for auth token and debug logging.
- **ApiConstants**: Path builders (e.g. `userRatingSummary`, `rateBooking`) in one place.
- **Services**: One per domain (`ReviewService`, `TripService`, `NotificationService`, …); call `ApiService` + `ApiConstants`; return maps or model lists.

### 3. State & UI
- **Provider**: `AuthProvider`, `AppLanguageProvider`; extend `ChangeNotifier` where needed.
- **Feature-first UI**: Screens live under `lib/features/<feature>/presentation/screens/`. Widgets use services + providers; avoid calling Dio directly in UI.
- **Light MVVM**: `lib/shared/presentation/base_view_model.dart`; example: `SimpleLoginViewModel` + `ListenableBuilder` on login. More ViewModels can be added per screen without moving folders again.
- **Pagination**: List screens use `page` / `limit` and “load more” where applicable (e.g. ratings).

### 4. Scalability
- **Pagination**: Keeps payloads small for reviews / user reviews.
- **Server as source of truth**: Bookings, trips, ratings — avoid duplicating server state locally beyond cache when needed.
- **Config**: `API_BASE_URL`, `SOCKET_URL`, timeouts — `EnvConfig` + `--dart-define` for staging / prod.

---

## `lib/` layout (current)

There is **no** top-level `lib/screens/` folder anymore. UI is grouped by **feature**.

```
lib/
  main.dart
  core/              – theme, brand, env, constants, localization, feedback, utils
  models/            – DTOs
  providers/         – global app state (auth, language)
  services/          – API access per domain (Dio via ApiService)
  utils/             – shared helpers (e.g. trip_self_book_guard)
  widgets/           – reusable widgets (e.g. RateRideDialog, BrandAppBarTitle)
  shared/
    presentation/
      base_view_model.dart
  features/
    landing/presentation/screens/
    auth/presentation/screens/     (+ view_models/ for login)
    trips/presentation/screens/
    profile/presentation/screens/
    home/presentation/screens/     – HomeScreen, role shells, passenger/driver/union homes
    notifications/presentation/screens/
    admin/presentation/screens/     – e.g. KYC document viewer
```

Cross-feature imports use relative paths from each file, or you can introduce `package:luharide/...` later via `pubspec` / analyzer settings.

**Migration history**: see `docs/mobile/FEATURE_FIRST_MVVM_MIGRATION.md`.  
**Ratings & reviews**: see `docs/mobile/RATINGS_AND_REVIEWS.md`.

---

## Notifications (in-app only)

- The product uses **in-app notifications**: list loaded from the **REST API**, shown via the **bell** (and related UI). No system ring / **FCM** / background push — that is **intentional** for now.
- `pubspec.yaml` does **not** include Firebase; add it only if you later want **external** pushes when the app is closed.

---

## OOP

- **Models**: Value objects; factory constructors and optional equality.
- **Services**: Encapsulate HTTP / sockets; one main responsibility per file.
- **Providers**: Thin orchestration for app-wide state; feature UI can add local `ChangeNotifier` / ViewModels as needed.
