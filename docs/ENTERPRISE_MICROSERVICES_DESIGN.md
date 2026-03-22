# LuhaRide — Enterprise Microservices Architecture (Design & Status)

**Document purpose:** Single source of truth for *what was built*, *why*, *what remains* for Uber/BlaBlaCar-scale reliability, and *how* Flutter + Node + PostgreSQL stay consistent.

**Related:** Short operational guide → [`MICROSERVICES_ARCHITECTURE.md`](./MICROSERVICES_ARCHITECTURE.md).

---

## 1. Executive summary — is “everything” done?

| Layer | Status | Notes |
|-------|--------|--------|
| **API path compatibility** | **Done** | All public `/api/*` routes are routed the same way through the **gateway** as in the monolith. Flutter can keep relative paths unchanged if the base URL points to the gateway. |
| **Logical service boundaries** | **Done (v1)** | Auth, Core (rides domain), Union, Platform (admin/pay/notify/reviews/uploads) + **Gateway** (HTTP proxy, rate limit, static `/uploads`, Socket.IO). |
| **Code layout** | **Shared monorepo** | Services **import** existing `backend/src/` controllers/routes — **no duplicated business logic**. This is intentional for correctness and speed. |
| **Data ownership** | **Single PostgreSQL** | One database, shared schema. **Not** database-per-service (yet). |
| **Enterprise / millions of users** | **Roadmap + patterns** | True at-scale systems add **Redis**, **message queues**, **read replicas**, **observability**, **multi-AZ**, **circuit breakers**, **Socket.IO adapter**, **PgBouncer**, etc. These are **documented below**; most are **not fully implemented** in code — and that is normal: you add them as load and SLOs demand. |

**Bottom line:** The **refactor to a microservices-style deployment with unchanged API paths** is **implemented**. Claiming **“millions of users, zero mistakes, fully enterprise”** as *fully delivered in code* would be misleading without the infra listed in §8–§10. This document separates **delivered v1** from **production-grade evolution**.

---

## 2. Principles & constraints

### 2.1 Non-negotiables (your requirements)

1. **Stable API paths** — `/api/trips/...`, `/api/auth/...`, etc. must not break clients.
2. **Flutter unchanged at the HTTP contract** — only base URL / env may change (gateway host).
3. **PostgreSQL** remains the system of record for transactional data.
4. **Robust & evolvable** — structure must allow scaling teams and traffic without rewriting everything.

### 2.2 Architectural decisions (ADR-style)

| Decision | Choice | Reasoning |
|----------|--------|-----------|
| **D1 — Gateway pattern** | Single entry (`gateway/server.js`) | One TLS termination point (with Nginx/ALB), one place for cross-cutting concerns (CORS, global rate limit, Socket.IO attach). |
| **D2 — Path-preserving reverse proxy** | `http-proxy-middleware` to upstreams | Zero client rewrites; order of route registration handles overlaps (`/api/simple-auth` before `/api/auth`). |
| **D3 — Shared codebase** | All services in one repo, shared `src/` | Avoids copy-paste bugs; migrations stay single-threaded; teams can later extract packages or repos. |
| **D4 — Single DB (v1)** | One PostgreSQL | ACID for bookings/trips/payments is simpler; split schemas later behind events if needed. |
| **D5 — Jobs in Core only** | `rateNotificationJob`, `rideCleanupJob` in `coreService.js` | Prevents duplicate cron when multiple API processes exist; **must not** run monolith + core together. |
| **D6 — Socket.IO on Gateway** | WebSocket on same origin as API | Flutter/mobile typically use one host; sticky sessions or Redis adapter needed only when **multiple gateway instances**. |

---

## 3. Current topology (as implemented)

```
                    ┌─────────────────────────────────────────┐
                    │           Clients (Flutter)              │
                    └────────────────────┬────────────────────┘
                                         │ HTTPS
                                         ▼
                    ┌─────────────────────────────────────────┐
                    │  API Gateway (port 3000)                 │
                    │  • /api → proxy + apiLimiter             │
                    │  • /uploads static                       │
                    │  • /health, /, /api, /api/health         │
                    │  • Socket.IO                             │
                    └─┬──────┬──────┬──────┬────────────────────┘
                      │      │      │      │
         /api/auth*   │      │      │      │  /api/admin, payments,
         /api/simple* │      │      │      │  notifications, reviews, uploads
                      ▼      ▼      ▼      ▼
                 ┌────────┐ ┌────────┐ ┌────────┐ ┌────────────┐
                 │ auth   │ │ core   │ │ union  │ │ platform   │
                 │ :3001  │ │ :3002  │ │ :3003  │ │ :3004      │
                 └────────┘ └────────┘ └────────┘ └────────────┘
                      │           │           │           │
                      └───────────┴───────────┴───────────┘
                                         │
                                         ▼
                              ┌──────────────────────┐
                              │   PostgreSQL         │
                              │   (shared schema)    │
                              └──────────────────────┘
```

### 3.1 Route → service mapping (authoritative)

| Prefix | Service | Rationale |
|--------|---------|-----------|
| `/api/auth`, `/api/simple-auth` | **auth** | Identity & session boundaries; can scale independently of trip search. |
| `/api/trips`, `/api/bookings`, `/api/drivers`, `/api/driver-verification` | **core** | Core ride-sharing domain + driver verification + **scheduled jobs**. |
| `/api/union` | **union** | Union-specific workflows isolated from core trip throughput. |
| `/api/admin`, `/api/payments`, `/api/notifications`, `/api/reviews`, `/api/uploads` | **platform** | Ops, money, comms, reputation, file APIs. |

**Gateway implementation:** `backend/gateway/server.js` — proxy order is explicit (longer paths first where needed).

### 3.2 Monolith parity

`backend/server.js` registers the **same** route sets; microservices mode is **optional** via separate processes. Default `npm start` = monolith for backward compatibility.

---

## 4. Component-by-component breakdown

### 4.1 Gateway

**Responsibilities:**

- Terminate HTTP from clients (TLS typically at Nginx/ALB in front).
- Apply **global** `apiLimiter` on `/api` (aligned with monolith behavior).
- Proxy to the correct upstream **without stripping path**.
- Serve **`/uploads`** from disk (must be **shared volume** if multiple gateway nodes).
- Host **Socket.IO** so clients use the same host as REST.
- Lightweight **health** (`/health` checks DB via shared pool).

**Future hardening:** Retries with backoff, circuit breaker (e.g. `opossum`), request IDs, OpenTelemetry.

### 4.2 Auth service

**Responsibilities:** JWT/session flows for `/api/auth` and `/api/simple-auth`.

**Scaling:** Stateless JWT validation scales horizontally; DB still used for users/secrets — pool sizing matters.

### 4.3 Core service

**Responsibilities:** Trips, bookings, drivers, driver verification POST/GET, **and** cron jobs.

**Critical ops rule:** Only **one** process should run these jobs (this implementation: **coreService only** in microservices mode).

### 4.4 Union service

**Responsibilities:** Union APIs only — reduces blast radius if union features misbehave.

### 4.5 Platform service

**Responsibilities:** Admin, payments, notifications, reviews, uploads API; also serves `/uploads` static on its own port (compose may mount volume for consistency).

---

## 5. Data & consistency model (v1)

- **Single PostgreSQL:** Transactions spanning booking + trip state remain straightforward.
- **Risk:** Any service can theoretically touch any table via shared code — **discipline** (or later **DB schemas per service** + APIs only) is required for long-term cleanliness.
- **Path to scale:** Read replicas for heavy GETs, PgBouncer for connection multiplexing, partitioning for huge tables (bookings history).
- **Formal mapping:** Migration `029_microservice_domain_registry.sql` adds `ms_table_domain` + `v_ms_tables_by_service` so each table has a documented **primary microservice**. See [`DATABASE_MICROSERVICE_MAPPING.md`](./DATABASE_MICROSERVICE_MAPPING.md).

---

## 6. Flutter integration (unchanged contract)

1. Set **base URL** to the **gateway** (e.g. `https://api.example.com` → port 3000 internally).
2. **WebSocket / Socket.IO** URL matches REST origin (gateway).
3. **No path changes** required for `/api/...` if the gateway is the only public host.

---

## 7. Docker & local ops

- **`infra/docker-compose-luharide-backend-microservices-redis-stack.yml`** — builds one image, runs five commands (gateway + four services + Redis).
- **`backend/Dockerfile`** — production-oriented Node 20 image.
- **Database:** Compose file assumes PostgreSQL is reachable via `DB_*` in `.env` (e.g. `host.docker.internal` or managed RDS URL).

---

## 8. Enterprise roadmap (not all implemented)

These are **industry-standard** additions for high scale; implement incrementally based on metrics and SLOs.

### 8.1 Reliability & resilience

| Capability | Purpose |
|------------|---------|
| **Health + readiness** | K8s liveness/readiness per service; gateway aggregates or fails fast. |
| **Circuit breakers** | Stop hammering failing upstreams. |
| **Timeouts & budgets** | Per-hop timeouts on proxy and DB. |
| **Idempotency keys** | Payments and booking creation (avoid double charge). |
| **DLQ** | Failed async work (notifications) not lost. |

### 8.2 Performance & scale

| Capability | Purpose |
|------------|---------|
| **PgBouncer** | Many app instances → bounded DB connections. |
| **Redis** | Cache hot reads, rate limit store, session if needed. |
| **Read replicas** | Scale read-heavy paths (search, listings). |
| **CDN** | Static uploads and assets. |
| **Horizontal pod autoscaling** | CPU/RPS-based scaling per deployment. |

### 8.3 Async & events (decouple domains)

| Capability | Purpose |
|------------|---------|
| **Kafka / Rabbit / SQS** | Trip completed → notify, update analytics, fraud checks without blocking HTTP. |
| **Outbox pattern** | Reliable events from PostgreSQL without dual writes. |

### 8.4 Realtime (multi-gateway)

| Capability | Purpose |
|------------|---------|
| **Redis adapter for Socket.IO** | Sticky sessions or pub/sub across gateway replicas. |
| **Geospatial** | Redis GEO or dedicated location service for driver matching at scale. |

### 8.5 Security (enterprise)

| Capability | Purpose |
|------------|---------|
| **mTLS** between gateway and services | Zero-trust internal mesh. |
| **Secrets manager** | No secrets in env files in prod. |
| **WAF** | Edge protection (Cloudflare, AWS WAF). |
| **Audit logs** | Admin and payment actions. |

### 8.6 Observability

| Capability | Purpose |
|------------|---------|
| **Structured logging** | Correlation IDs across gateway → service. |
| **Metrics** | Prometheus + RED/USE dashboards. |
| **Tracing** | OpenTelemetry Jaeger/Tempo. |
| **Alerting** | SLO burn rates, error budget. |

---

## 9. Anti-patterns to avoid

1. **Running monolith + core microservice** — duplicate cron / double side effects.
2. **Oversized pools** — 5 × 20 max connections without PgBouncer can exhaust small Postgres tiers.
3. **Multiple gateways without Socket.IO adapter** — broken realtime across instances.
4. **Treating v1 split as “fully isolated domains”** — shared DB + shared code means **logical** boundaries; **physical** isolation is a later investment.

---

## 10. Verification checklist (before claiming production-ready at scale)

- [ ] Load test gateway + each upstream under expected RPS.
- [ ] Chaos: kill one service, observe gateway behavior and client UX.
- [ ] DB: connection count under load; add PgBouncer if needed.
- [ ] Jobs: exactly one scheduler active in prod.
- [ ] Socket.IO: test with 2+ gateway replicas if applicable.
- [ ] Payments: idempotency and webhook verification documented and tested.

---

## 11. Conclusion

- **Implemented:** Path-stable **API gateway**, **four domain-aligned Node services**, **shared PostgreSQL**, **Docker Compose**, **operational docs**, **monolith preserved** as default.
- **Not a substitute for:** Managed infra, queues, replicas, full observability stack — those are the **next investments** for “millions of users” reliability.

This design is **correct for v1 decomposition** and **honest** about what **enterprise-grade** requires beyond code structure. Evolve the platform using §8 as a prioritized backlog tied to real SLOs and traffic.

---

*Last updated: aligned with `backend/gateway/server.js`, `backend/microservices/*.js`, `backend/server.js`, and `infra/docker-compose-luharide-backend-microservices-redis-stack.yml`.*
