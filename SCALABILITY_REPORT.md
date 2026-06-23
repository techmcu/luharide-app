# LuhaRide — Architecture & Scalability Assessment (1 → 100k → 1 Cr users)

Honest, code-grounded review of every moving part (Firebase, Ola, Redis, PM2,
DB, frontend, dependencies) + what to do at each scale tier, from DSA / system-
design / business-logic angles.

_Prepared: 2026-06-23._

---

## TL;DR
- **Backend is genuinely production-grade and already microservices + clustered.**
  You do NOT need to "make it microservices" — it already is. Scale **horizontally**
  (more instances / replicas) first; do not over-split now.
- Current setup comfortably handles **1 → ~10–20k users**. With the tier upgrades
  below it scales to **100k → 1M → 1 Cr**.
- The biggest scale risks are **operational/infra**, not the app code:
  shared staging↔prod DB, single Redis, uploads on local disk, and the
  `available_seats` counter.

---

## A. Per-dependency health

| Dependency | State today | Verdict | Scale action |
|-----------|-------------|---------|--------------|
| **Backend (Node/Express)** | Microservices: gateway + auth/core/union/platform; `sharedApp` baseline; helmet/CORS/compression | ✅ Strong | Add instances; keep stateless |
| **PM2** | core + gateway **cluster (2 each, env-tunable)**; others fork; `max_memory_restart 500M` | ✅ Good | Raise `LUHA_CORE_INSTANCES`/`LUHA_GATEWAY_INSTANCES`; multi-VPS + LB later |
| **PostgreSQL + PostGIS** | Per-service pools (core max 25), `queryRead` (replica-ready), strong indexes (geo bbox, status+departure, bookings) | ✅ Good | PgBouncer (pooler) → read replicas → partition trips/bookings by date at 1M+ |
| **Redis** | Circuit-breaker, infinite reconnect, **fail-open to in-memory**, Telegram alerts; used for rate-limit + Socket.IO adapter + cache | ✅ Good | Single instance = SPOF; move to managed/HA Redis at 100k+ |
| **Firebase / FCM** | Batched admin broadcast, stale-token cleanup, async | ✅ OK | Push via a **queue** (BullMQ) at scale so broadcasts never block requests |
| **Ola Maps** | In-memory cache + region bias; quota-limited external API | 🟡 Watch | Aggressive cache (longer TTL) + **haversine fallback** when Ola down/quota; per-IP search limit already exists |
| **Frontend (Flutter)** | Push-first (Socket.IO), **zero polling** now, responsive seat layout, cached images | ✅ Good | Stateless; fine at any scale. Finish responsive audit (see UI_AUDIT_REPORT.md) |
| **Dependencies** | Mainstream, maintained (dio, provider, pg, ioredis, socket.io, firebase) | ✅ | Keep patched; `npm ci` in CI ✅ |

---

## B. Should we go "more microservices" now? — NO
- You already have a clean **gateway + 4 domain services** split. That's the right
  granularity for this domain.
- Splitting further now = more ops complexity, network hops, distributed-txn pain —
  **without** a scale need yet. **Premature.**
- Correct path: scale the **hot service (core/ride)** with more cluster instances,
  add read replicas, and only extract a new service when ONE domain becomes a real
  bottleneck (e.g. notifications → its own worker + queue).

---

## C. DSA / system-design points (for 1 → 1 Cr)

1. **Search is the hardest path.** Today: indexed bbox pre-filter → `CAND_LIMIT 200`
   candidates → JS scoring/sort. Fine now. At 1M+ trips/day:
   - keep the candidate cap, push more ranking into SQL, and consider PostGIS
     `geography` + GiST/SP-GiST for true nearest-neighbour, or a search service
     (Elasticsearch/Typesense) if filters grow.
2. **`available_seats` is a mutated counter** (book/cancel/lock/lifecycle). Add a
   **nightly reconciliation** (recompute from bookings+locks) — or make the
   computed value (already in booked-seats) the source of truth. Prevents drift =
   prevents overbooking at scale.
3. **Hot rows / concurrency:** booking uses `FOR UPDATE` row locks (correct). At
   high contention per popular trip, keep transactions short (they are).
4. **Idempotency** on booking ✅ — essential at scale (retries/double-taps).
5. **Pagination everywhere** (my-bookings/my-trips already paginate) — never return
   unbounded lists.
6. **Background work → a real queue** (BullMQ/Redis) at 100k+: FCM fan-out,
   poster PDF gen (CPU-heavy), rate notifications. Today they're cron/interval +
   advisory lock (fine to ~tens of k).

---

## D. Business-logic correctness (scale-safe)
- Ride lifecycle (auto start/complete), seat locks, cancel penalties, ride limits,
  fare ceiling — all enforced server-side ✅ (clients can't bypass).
- Keep **all constraints server-authoritative** (already the case).
- Add tests for each rule (test-before-push) so scale changes don't regress logic.

---

## E. 🔴 Top risks to fix BEFORE big scale (infra/ops)
| # | Risk | Impact at scale | Fix |
|---|------|-----------------|-----|
| 1 | **Staging ↔ Prod share ONE DB/Redis/uploads** | A bad test/migration hits real users; can't load-test safely | Give staging its own DB + Redis + uploads |
| 2 | **Uploads on local disk (symlinked)** | Breaks with multiple app servers; disk fills | Move to **object storage (S3/Spaces)** + CDN |
| 3 | **Single Redis** (SPOF) | Redis down → rate-limit degrades, socket fan-out breaks | Managed/HA Redis |
| 4 | **`available_seats` drift** | Overbooking / wrong availability | Reconciliation job (§C2) |
| 5 | **Ola quota / no fallback** | Fare ceiling skipped, geocode fails under load | Cache + haversine fallback |
| 6 | **DB = single instance** | Read load saturates at scale | PgBouncer → read replicas |

---

## F. Scaling roadmap by user count

**1 – 10k users (today):** current single-VPS, cluster (core+gateway ×2), pooled
DB, Redis. ✅ Works. Just fix risks #1 (staging DB) and #4 (reconciliation).

**10k – 100k:** PgBouncer; raise core instances; HA/managed Redis; uploads → object
storage + CDN; serve `/health` from nginx; separate DB server; move FCM/poster to
a queue.

**100k – 1M:** read replicas (point `queryRead` at them); multiple app servers
behind a load balancer; CDN for Flutter web + images; dedicated notification
worker; metrics + tracing (Prometheus/Grafana, OpenTelemetry); autoscaling.

**1M – 1 Cr:** partition/shard `trips`/`bookings` (by date/region); dedicated
search service (PostGIS-tuned or Elasticsearch); message queue (BullMQ/Kafka) for
all async; multi-region read replicas + caching; aggressive CDN; capacity tests.

---

## G. Recommended order of work
1. **Fix infra risks #1, #2, #3** (separate staging DB, object storage, HA Redis) —
   these unblock safe scaling and remove the scariest failure modes.
2. **`available_seats` reconciliation** + **Ola fallback** (correctness/resilience).
3. **PgBouncer + read replica wiring** (`queryRead` already abstracted — easy win).
4. **Queue for FCM/poster** when broadcasts/users grow.
5. Keep adding **tests per logic change**; load-test before each tier jump.

> Bottom line: the **code/architecture is already good and microservices-ready**.
> The work to reach 1 Cr is mostly **infra & data-layer scaling + a few resilience
> fixes**, done tier-by-tier — not a rewrite.
