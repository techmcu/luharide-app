# LuhaRide — Polling & Background Activity Reference

A complete, category-wise map of every recurring / background network activity in
the LuhaRide app (Flutter client + Node backend): **what it is, how often it runs,
whether it touches the server, what work it does, and how it behaves as users grow.**

> **Design philosophy — push-first, minimal polling.** Real-time updates use a
> persistent Socket.IO channel (server pushes changes). Connectivity uses OS
> events. There is **no per-user server polling** anywhere in the client. The
> only recurring server-side work is a small set of single-instance scheduled
> jobs whose load is independent of the number of users.

_Last updated: 2026-06-23._

---

## Legend

- **Server hit?** — does this activity send requests to our backend?
- **Type** — Push (server → client), Event-driven (OS/SDK triggers), Timer (client-local), Scheduled job (server cron/interval), One-shot (fires once, not recurring).
- **Scales with users?** — does load grow as the number of users grows?

---

## Category A — Real-time Push (NOT polling)

The primary update mechanism. The client keeps one persistent connection open;
the server pushes events the instant something changes.

| Item | Mechanism | Settings | Work it does | Server hit? | Scales with users? |
|------|-----------|----------|--------------|-------------|--------------------|
| Live updates (seat booked, trip status, notifications, driver location) | Socket.IO persistent connection | transports: `websocket` (primary), `polling` (fallback only); auth via JWT | Receives `trip-updated`, `notification:new`, `driver-location` events pushed by server | Persistent connection (no repeated requests) | **Connection count** grows with concurrent users (memory/file-descriptors), not request volume |
| Reconnect on drop | Socket.IO auto-reconnect + manual backoff | 12 attempts, 1500 ms base delay (backoff), 20 s connect timeout | Re-establishes the line after a network drop / server restart | Reconnect attempts only while disconnected | A server restart causes a reconnect burst (see Scaling Notes) |

**Why this is not polling:** the client does not ask "any updates?" on a timer.
The server decides when to send. This is the same model Uber/Ola/WhatsApp use.

---

## Category B — Event-driven Connectivity (NOT polling)

Detects online/offline without ever pinging the server on a timer.

| Item | Mechanism | Trigger | Work it does | Server hit? | Scales with users? |
|------|-----------|---------|--------------|-------------|--------------------|
| Network status | `connectivity_plus` (OS events) | OS pushes wifi/mobile/none changes | Flips the app online/offline banner | **No** | No (zero server load) |
| Reachability confirm | Reactive (Dio interceptor) | Result of a **real** API call | Marks online on any success; offline only on a true connection/timeout error | Piggybacks on real requests (no extra calls) | No |

> **History:** this previously pinged `GET /health` every 15 s **per active user**
> (at 100k users ≈ 6,600 req/s of pure health traffic). It was replaced with the
> event-driven approach above — that per-user poll no longer exists.

---

## Category C — Client-side Timers (local only, NO server hit)

UI timers that never touch the backend.

| Item | Interval | Work it does | Server hit? |
|------|----------|--------------|-------------|
| OTP resend countdown | `Timer.periodic` 1 s | Counts down the "Resend OTP" cooldown on screen | No |
| Search / location debounce | `Timer` 300 ms (one-shot per keystroke) | Waits until the user stops typing, then fires **one** search — *reduces* server calls | Only the single resulting search |

---

## Category D — One-shot Retries / Delays (not recurring)

Fire once in response to a specific event; not loops.

| Item | Timing | Work it does | Server hit? |
|------|--------|--------------|-------------|
| 502 / 503 auto-retry | `Future.delayed` 2 s, **one** retry | Retries a request once when a gateway/service is briefly unavailable | One extra request, only on failure |
| 401 → token refresh + retry | On demand | Silently refreshes the access token once, retries the original request | One refresh + one retry, only on 401 |
| UI stagger delays (landing, help) | `Future.delayed` (ms) | Cosmetic animation/sequencing | No |

---

## Category E — Backend Scheduled Jobs (server-side, single-instance)

Recurring server work. **Each tick runs one bounded, indexed query** under a
PostgreSQL advisory lock, and the jobs start **only in the core service (or the
monolith)** — never duplicated across microservices. Their cost is **independent
of the number of users.**

| Job | Schedule | Work it does | Guards | Scales with users? |
|-----|----------|--------------|--------|--------------------|
| Trip lifecycle (auto start / complete) | every **2 min** (`setInterval`) | Starts trips at departure time, completes them at arrival time, cancels stale pendings | pg advisory lock; single instance | No (one query/tick) |
| Pending booking expiry | every **2 min** | Cancels bookings the driver never responded to, restores seats | pg advisory lock | No |
| Rate-reminder notifications | every **15 min** | Sends "rate your ride" prompts after completed trips | pg advisory lock | No |
| Ride cleanup / maintenance | daily **18:30 IST** (cron) | Deletes old trips, expired tokens/OTPs; FCM token cleanup | cron, single run | No |
| Daily stats aggregation | daily **18:35 IST** (cron) | Aggregates yesterday's metrics for the admin dashboard | cron, single run | No |
| Socket rate-limit cleanup | `setInterval(window)` `.unref()` | Clears expired entries from an **in-memory** map (no DB) | in-process only | No |

---

## Scaling Notes & Dangerous Items

| Concern | Severity | Behaviour as users grow | Mitigation |
|---------|----------|-------------------------|------------|
| ~~Per-user `/health` poll (15 s)~~ | ✅ Removed | Was: N users → N/15 req/s (100k ≈ 6,600 req/s) → event loop saturates → latency rises → 503s for everyone | Replaced with event-driven connectivity (Category B) |
| Socket.IO concurrent connections | 🟡 Watch | Each open app = 1 persistent connection. 100k concurrent = 100k connections = memory + file descriptors per gateway process | Redis adapter (present) for cross-process fan-out; scale gateway processes horizontally; raise OS file-descriptor limit (`ulimit`) |
| Socket reconnect burst on restart | 🟡 Watch | On a server restart, all clients reconnect within ~1.5–18 s → CPU spike; some users see a brief reconnect lag | Backoff (already configured) + multiple gateway processes smooth the burst |
| Backend scheduled jobs | 🟢 Safe | Load does **not** grow with users (one query/tick). Only data growth could slow the query | Queries are indexed (status, departure_time); safe into the millions of rows |
| Client timers (OTP, debounce) | 🟢 Safe | No server impact at any scale | — |

---

## Summary

- **No per-user server polling exists in the client.** Updates are push (Socket.IO);
  connectivity is OS-event-driven; all client timers are local-only.
- **Backend recurring work** is a handful of single-instance, advisory-locked
  sweepers whose cost is constant regardless of user count.
- **The only axis that grows with users is the number of concurrent Socket.IO
  connections** — a normal property of any real-time app, handled by the Redis
  adapter and horizontal gateway scaling, not by polling.

**One line:** LuhaRide is push-first with zero per-user polling; it scales on
connection count (memory), not on request volume.
