# LuhaRide — polling, timers, and periodic work

Inventory of **repeating** or **scheduled** work in this repo (backend + Flutter app), with **intervals** so you can tune load vs responsiveness.

## Backend (Node)

| Location | What | Interval / schedule | Notes |
|----------|------|---------------------|--------|
| `backend/src/jobs/rateNotificationJob.js` | Reads `pending_rate_notifications` (due rows), inserts in-app notifications, deletes queue rows | **`setInterval` every 60_000 ms (1 minute)** | Also runs once immediately on `start()`. Uses PostgreSQL advisory lock so multiple processes do not double-send. **Highest-frequency server poll.** |
| `backend/server.js` | Starts jobs above | On process listen | Same jobs also started from `backend/microservices/coreService.js` if you run the core microservice — use **one** deployment pattern or rely on advisory locks. |
| `backend/microservices/coreService.js` | Starts `rateNotificationJob` + `rideCleanupJob` | On service start | Duplicate **timer** instances if monolith **and** core MS both run (lock still protects DB work). |
| `backend/src/jobs/rideCleanupJob.js` | Union schedule delete, trip auto-complete, old trip purge | **Cron `30 18 * * *`** (daily, ~midnight IST) **+** **`30 0 * * *`** (~06:00 IST safety) **+** **once at startup** | Not a tight loop; cheap to keep. |
| `backend/src/services/tokenService.js` | `cleanupExpiredTokens()` deletes expired refresh tokens | **Not scheduled** — function exists but **no `setInterval`/cron** calls it in this repo | Optional: hook to daily cron if table grows. |
| `backend/gateway/server.js` | `req.setTimeout` | Per HTTP request | Not polling. |

### Ideas to reduce backend polling load

- **Rate notification job**: Increasing `INTERVAL_MS` in `rateNotificationJob.js` (e.g. 2–5 minutes) cuts DB queries; notifications may arrive slightly later after `send_after`.
- **Single job runner**: Ensure only one Node process runs the rate job in production (or keep advisory lock and accept idle polls on replicas).

## Flutter app (`mobile/lib`)

| Location | What | Interval | Notes |
|----------|------|----------|--------|
| `screens/auth/otp_verification_screen.dart` | Resend OTP countdown UI | **`Timer.periodic` every 1 second** for up to **60** ticks | Only while OTP screen is open; stops at 0. |
| `screens/home/passenger_home_screen.dart` | Location suggestion API after typing | **`Timer` debounce 350 ms** (one-shot per keystroke burst, not a loop) | `_suggestionDebounce` — reduces API calls vs per-key. |
| `services/realtime_socket_service.dart` | Socket.IO | Library **reconnect delay 1500 ms**, up to **12** attempts; manual fallback **`Timer` 4 seconds** after `connect_error` / `reconnect_failed` | Event-driven, not a fixed background poll. |
| SnackBars / `Future.delayed` | UI feedback | 2–5 s typical | **One-shot**, not periodic server polling. |
| `services/api_service.dart` | HTTP timeouts | 60–90 s | Not polling. |

### Screens explicitly **without** auto-polling (manual / pull / one-shot)

- `passenger_my_rides_screen.dart` — comments: pull-to-refresh.
- `union_registration_screen.dart` — manual check button.
- `profile_screen.dart` — driver verification check: single call when user acts.

## Summary

- **Only true high-frequency server poll** in-app code: **rate notification job every 1 minute**.
- **Flutter**: only **1 s** periodic timer on **OTP** screen; rest is debounce, socket reconnect, or one-off delays.
