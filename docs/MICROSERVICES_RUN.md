# LuhaRide — 4 microservices + API Gateway

**Haan, convert possible hai** — repo mein **already split** hai (shared PostgreSQL, same codebase paths).

| # | Service | Port (default) | Routes (proxied by gateway) |
|---|---------|----------------|----------------------------|
| **Gateway** | Public entry + Socket.IO + global rate limit | `3000` | `/`, `/health`, `/uploads`, `/api/*` → below |
| **1. Auth** | Login, signup, JWT, OTP | `3001` | `/api/auth`, `/api/simple-auth` |
| **2. Core** | Trips, bookings, drivers, verification, cron jobs | `3002` | `/api/trips`, `/api/bookings`, `/api/drivers`, `/api/driver-verification` |
| **3. Union** | Union admin flows | `3003` | `/api/union` |
| **4. Platform** | Admin, payments, notifications, reviews, uploads | `3004` | `/api/admin`, `/api/payments`, `/api/notifications`, `/api/reviews`, `/api/uploads` |

**Mobile / Flutter:** `API_BASE_URL` = **gateway** URL only (e.g. `http://localhost:3000` or `https://api.yourdomain.com`) — paths **same** as monolith.

**Phase 1 (local verify):** [`LUHARIDE_MICROSERVICES_MIGRATION_STEP_BY_STEP.md`](./LUHARIDE_MICROSERVICES_MIGRATION_STEP_BY_STEP.md) — `npm run develop:luharide-microservices-local-five-services` then `npm run verify:luharide-microservices-health-endpoints`. Status: [`LUHARIDE_MICROSERVICES_PHASE_ONE_IMPLEMENTATION_STATUS.md`](./LUHARIDE_MICROSERVICES_PHASE_ONE_IMPLEMENTATION_STATUS.md).

---

## Option A — Monolith (simplest VPS)

```bash
cd backend
npm install
cp .env.example .env   # fill secrets
node server.js
```

Ek process: API + Socket.IO + jobs.

---

## Option B — Microservices (local dev)

Terminal 1 se **saari** services:

```bash
cd backend
npm install
npm run develop:luharide-microservices-local-five-services
```

Ya alag terminals:

```bash
npm run start:gateway
npm run start:ms:auth
npm run start:ms:core
npm run start:ms:union
npm run start:ms:platform
```

Order: pehle 3001–3004, phir gateway `3000` (ya `develop:luharide-microservices-local-five-services` sab ek saath).

---

## Option C — Docker

Repo root:

```bash
docker compose -f infra/docker-compose-luharide-backend-microservices-redis-stack.yml up --build
```

---

## Production (VPS)

- **Nginx** → sirf **gateway** `:3000` expose karo (ya unix socket).
- Internal: `AUTH_URL=http://127.0.0.1:3001` … (localhost) — PM2 se 5 apps.
- Sample: `backend/pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs` (PM2).

**Dhyan:** Har service apna **DB pool** kholti hai — `PG_POOL_MAX` chhota rakho agar 5 processes hon (e.g. max 8–10 each).

**Redis:** VPS scale / Docker stack — [`PHASE_REDIS_AND_OBSERVABILITY.md`](./PHASE_REDIS_AND_OBSERVABILITY.md). Full steps: [`VPS_DEPLOY_CHECKLIST.md`](./VPS_DEPLOY_CHECKLIST.md).

---

## Kya abhi “pure” DB-per-service nahi hai?

**Sahi pakde:** Abhi **ek PostgreSQL** shared hai — ye **practical first step** (strangler). Baad mein schema/service split alag migration.

---

*See also: `docs/ARCHITECTURE_MICROSERVICES_ROADMAP.md`*
