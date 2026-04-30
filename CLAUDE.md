# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LuhaRide is an Uttarakhand taxi booking platform — a legal taxi aggregator with digital seat booking, real-time tracking, and union partnerships. The repo contains a Flutter mobile/web app (`mobile/`) and a Node.js backend (`backend/`), plus infrastructure configs (`infra/`) and a pre-built Flutter web deploy (`webapp/`).

## Common Commands

### Backend (run from `backend/`)
```bash
npm run dev                 # Monolith on port 3000 (nodemon)
npm run dev:stack           # Gateway (3010) + 4 microservices (3001-3004) via concurrently
npm test                    # Jest with coverage
npm test -- --testPathPattern=<pattern>  # Single test file
npm run migrate             # Run DB migrations
npm run seed                # Seed sample data
npm run phase4:verify:stack # Verify production PM2 stack health
```

### Mobile (run from `mobile/`)
```bash
flutter pub get
flutter run                                          # Default device
flutter run --dart-define=USE_LOCAL_API=true          # Point at local backend (port 3000)
flutter run --dart-define=USE_LOCAL_API=true --dart-define=LOCAL_API_PORT=3010  # Local gateway
flutter test                                         # All tests
flutter test test/core/env_config_test.dart           # Single test
flutter analyze --no-fatal-infos                     # Lint (matches CI)
flutter build web                                    # Web build → build/web/
```

### CI (GitHub Actions)
- **CI** (`ci.yml`): gitleaks secret scan, `npm test --ci` (backend), `flutter analyze` + `flutter test` (mobile). Runs on push to `main` and all PRs.
- **Deploy** (`deploy-vps.yml`): triggers after CI passes on `main`. SSHs to VPS, pulls, `npm ci`, migrates, reloads PM2 ecosystem, syncs `webapp/` and `infra/static-site-luharide-root/` to nginx roots, runs health checks.

## Architecture

### Backend: Monolith + Microservices (same codebase)

Two run modes share the same `src/` code:

- **Monolith** (`server.js`): single Express app on port 3000. Used for local dev and emergency rollback.
- **Microservices** (production): 4 domain services + 1 API gateway, managed by PM2 (`pm2-ecosystem-*.config.cjs`).
  - `authService.js` (:3001) — auth, OTP, JWT, user profiles
  - `coreService.js` (:3002) — trips, bookings, drivers, reviews, uploads
  - `unionService.js` (:3003) — union registration, dashboard, union admin
  - `platformService.js` (:3004) — platform admin, KYC, payments, notifications
  - `gateway/server.js` (:3000) — reverse proxy via `http-proxy-middleware`, Socket.IO, health aggregation

Each microservice uses `microservices/sharedApp.js` for the common Express baseline (helmet, CORS, compression, error handling) then mounts only its own routes.

**Key backend patterns:**
- `src/config/env.js` validates required env vars at startup (fail-fast)
- `src/middleware/auth.js` — JWT `authenticate` middleware; roles checked per-route
- `src/middleware/rateLimiter.js` — rate limiting with optional Redis backing (`rate-limit-redis`)
- `src/socket/` — Socket.IO with Redis adapter for cross-process pub/sub
- `src/jobs/` — cron jobs (ride cleanup, rate notifications) using `node-cron` with `pg_advisory_lock`
- Tests are colocated (`*.test.js` next to source) and use Jest + supertest

**Database:** PostgreSQL with PostGIS. Migrations in `backend/migrations/` run sequentially via `run-migrations.js`. Redis for sessions/rate-limits/Socket.IO adapter.

### Mobile: Feature-first Flutter

State management: **Provider** (`ChangeNotifier` pattern). `AuthProvider` is the root; it wraps `AuthService` → `ApiService` (Dio singleton).

```
mobile/lib/
├── core/           # EnvConfig, theme, brand, constants, KYC utilities, localization
├── features/       # Feature modules (auth, home, profile, trips, admin, notifications, landing)
│   └── <feature>/presentation/screens/   # Screens per feature
├── models/         # Data models (UserModel, TripModel, SeatLayout, VehicleCatalog, etc.)
├── providers/      # AuthProvider, AppLanguageProvider
├── services/       # API service (Dio), auth, trips, reviews, uploads, Socket.IO, unions
├── widgets/        # Shared widgets
└── main.dart       # App entry; MultiProvider → MaterialApp
```

**API connectivity:** `EnvConfig` resolves the API base URL at compile time via `--dart-define`. Debug+`USE_LOCAL_API` → `127.0.0.1` (web) or `10.0.2.2` (Android emulator). Release → `https://luharide.cloud/api`. All requests go through `ApiService.buildApiUrl()` to avoid Dio base-URL merge issues.

**Web support:** conditional imports (`dio_adapter_config.dart` / `dio_adapter_config_web.dart`). Web build output is committed to `webapp/` and served by nginx.

**Roles:** passenger, driver, union_admin, admin. `RoleExclusivity` enforces mutual exclusion between independent driver and union representative paths.

### Infrastructure
- VPS with nginx (split config: root site at `luharide.cloud`, Flutter web app at `luharide.cloud/app/`, API proxied at `/api/` and `/socket.io/`)
- PM2 manages the 5-process microservice stack in production
- `infra/` contains nginx example configs, docker-compose for local Redis, and deploy scripts

## Important Conventions

- Backend tests live next to source files (`*.test.js`), not in a separate `__tests__/` directory
- `pubspec.lock` is gitignored; `package-lock.json` is committed (CI uses `npm ci`)
- KYC document handling has watermarking/PDF-merge utilities in `src/utils/kyc*.js` — these process uploaded images server-side
- The `.deploy-token`, `deploy_key*` files are gitignored secrets — never commit replacements
