# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Token Efficiency

**Before re-reading files**, check `CODEBASE_MAP.md` (gitignored, local only) — it has the full file tree, controller→route mapping, service layer map, and key patterns. Use it to jump directly to the right file instead of exploring. Also check memory entries for project status, completed work, and user preferences.

**Barrel controllers:** `tripController.js`, `platformAdminController.js`, and `unionController.js` are barrel files that re-export from sub-controllers in subdirectories. Routes always import from the barrel — never change route imports when splitting controllers.

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

### CI / CD (GitHub Actions)
- **CI** (`ci.yml`): gitleaks secret scan, `npm test --ci` (backend), `flutter analyze` + `flutter test` (mobile). Runs on push to `main` and all PRs.
- **Staging Deploy** (`deploy-vps.yml`): triggers after CI passes on `main`. Builds Flutter web with staging API URL, deploys to VPS staging directory, starts staging PM2 processes, runs health checks. Staging stays running permanently.
- **Production Deploy** (`deploy-production.yml`): manual trigger (`workflow_dispatch`). Builds Flutter web with production API URL, deploys to VPS production directory, runs `npm run migrate`, reloads PM2 production stack, syncs nginx roots, runs full health checks. Has automatic rollback on failure.

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

### Infrastructure — Staging & Production (same VPS)

Both environments run on the same VPS. **They share the same PostgreSQL database, Redis, and uploads directory.** Any data change on staging affects production and vice versa.

#### Production
- **URL:** `https://luharide.cloud` (root site) / `https://luharide.cloud/app/` (Flutter web)
- **API:** `https://luharide.cloud/api/v1` → nginx proxies to gateway on port **3000**
- **PM2 config:** `pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs`
- **Ports:** gateway :3000, auth :3001, core :3002, union :3003, platform :3004
- **VPS paths:** code at `/var/www/luharide-backend`, web at `/var/www/luharide-web`, root site at `/var/www/luharide-cloud`
- **Deploys:** `deploy-production.yml` (manual trigger) — runs migrations, reloads PM2, has rollback

#### Staging
- **URL:** `https://staging.luharide.cloud` (root) / `https://staging.luharide.cloud/app/` (Flutter web)
- **API:** `https://staging.luharide.cloud/api/v1` → nginx proxies to staging gateway on port **3100**
- **PM2 config:** `pm2-ecosystem-staging.config.cjs`
- **Ports:** gateway :3100, auth :3101, core :3102, union :3103, platform :3104
- **VPS paths:** code at `/var/www/luharide-staging`, web at `/var/www/luharide-web-staging`
- **Deploys:** `deploy-vps.yml` (auto on main push) — copies production .env, does NOT run migrations
- **Flutter web build:** `--dart-define=API_BASE_URL=https://staging.luharide.cloud/api/v1 --dart-define=SOCKET_URL=https://staging.luharide.cloud`

#### Shared resources (CAUTION)
- `.env` is copied from production to staging — same DB credentials, JWT secret, Redis
- Uploads directory is symlinked from production
- Test data created on staging will appear in production
- Staging does not run its own migrations — relies on production having run them

#### Key rules when making changes
- Any new migration: will only apply when production deploys (staging doesn't run `npm run migrate`)
- Backend code changes: must update both monolith (`server.js`) and microservice entry points (`microservices/*.js`) and gateway (`gateway/server.js`) where applicable
- Flutter web changes: staging build uses `API_BASE_URL` dart-define; production build uses default `EnvConfig._productionApiBase`
- `infra/` contains nginx example configs, docker-compose for local Redis, and deploy scripts

## Important Conventions

- Backend tests live next to source files (`*.test.js`), not in a separate `__tests__/` directory
- `pubspec.lock` is gitignored; `package-lock.json` is committed (CI uses `npm ci`)
- KYC document handling has watermarking/PDF-merge utilities in `src/utils/kyc*.js` — these process uploaded images server-side
- The `.deploy-token`, `deploy_key*` files are gitignored secrets — never commit replacements
