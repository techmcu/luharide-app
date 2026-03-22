# LuhaRide — Microservices Architecture

This document describes the **optional** split of the monolithic Node.js API into **path-preserving** services behind an **API gateway**. **Flutter and all clients keep the same URLs** (`/api/...`, `/socket.io`, `/uploads`).

> **Full design (decisions, ADRs, enterprise roadmap):** [`ENTERPRISE_MICROSERVICES_DESIGN.md`](./ENTERPRISE_MICROSERVICES_DESIGN.md)  
> **DB ↔ services (registry + migration 029):** [`DATABASE_MICROSERVICE_MAPPING.md`](./DATABASE_MICROSERVICE_MAPPING.md)  
> **Status:** Gateway + 4 services + Docker = **done**. Uber-scale items (Redis, queues, replicas, full observability) = **documented roadmap**, not all implemented in code.

## What was wrong with “only monolith”?

Nothing is “wrong” for a single VPS — a monolith is simpler to deploy. Microservices **trade complexity** for **independent scaling** and **team boundaries**. This project supports **both**:

| Mode | Command | Use when |
|------|---------|----------|
| **Monolith** (default) | `npm start` → `server.js` | Single server, simplest ops |
| **Gateway + services** | Docker Compose or 5 terminals + `gateway/server.js` | You want horizontal scaling / isolation |

## Service map (same PostgreSQL, shared schema)

| Service | Port (default) | Routes |
|---------|------------------|--------|
| **gateway** | 3000 | Proxies HTTP + **Socket.IO** + `/uploads` static + `/health` |
| **auth** | 3001 | `/api/auth`, `/api/simple-auth` |
| **core** | 3002 | `/api/trips`, `/api/bookings`, `/api/drivers`, `/api/driver-verification` + **cron jobs** |
| **union** | 3003 | `/api/union` |
| **platform** | 3004 | `/api/admin`, `/api/payments`, `/api/notifications`, `/api/reviews`, `/api/uploads` |

**Public URL** always points to the **gateway** (e.g. `https://api.yourdomain.com` → port 3000). Nginx SSL terminates here; upstreams can stay HTTP on localhost.

## What did NOT change

- **All API paths** (`/api/trips/search`, `/api/bookings`, …) — unchanged.
- **PostgreSQL** — single database; no per-service DB split (pragmatic; can evolve later).
- **Controllers** — live under `backend/src/`; services **import** them (no duplication).

## Risks & mitigations

1. **Connection pool multiplication** — each Node process creates a `pg` pool (`max: 20` in `database.js`). Five services ⇒ up to **~100 connections** if all saturate. **Mitigation:** lower `max` per process via env, or **PgBouncer**, or fewer processes until load grows.
2. **Jobs run twice** — `rateNotificationJob` / `rideCleanupJob` only start in **`coreService.js`**. **Do not** run `server.js` (monolith) **and** `coreService.js` in production.
3. **Socket.IO** — attached to **gateway** only; clients keep using the same origin as the API.
4. **Uploads** — gateway serves **`/uploads`** from disk; upload **API** routes go to **platform**. Ensure `uploads/` volume is shared on all nodes if you scale out.
5. **Failure propagation** — if `auth` is down, login fails. Use **health checks**, **retries**, and **circuit breakers** (future) in the gateway.

## Deployment checklist

1. `cd backend && npm install` (adds `http-proxy-middleware`).
2. Set env: `AUTH_URL`, `CORE_URL`, `UNION_URL`, `PLATFORM_URL` (Docker internal hostnames) and `GATEWAY_PORT=3000`.
3. Start **all five** processes (or `docker compose -f infra/docker-compose-luharide-backend-microservices-redis-stack.yml up`).
4. Point Flutter `API_BASE_URL` / `SOCKET_URL` to **gateway** host/port only.
5. **Never** run monolith `server.js` together with `coreService.js` (duplicate jobs).

## Future hardening (not implemented here)

- Per-service **DB schemas** or **separate databases** + eventual consistency.
- **Message queue** (SQS/Rabbit) for async notifications.
- **Redis** for distributed rate limit + Socket.IO adapter if multi-gateway.
- **Kubernetes** + Helm when you outgrow one VM.

## Rollback

Use **`npm start`** (monolith) only — no gateway, no microservices processes.
