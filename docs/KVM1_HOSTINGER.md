# Hostinger KVM1 (basic VPS) — recommended settings

Single small box: **one Node process**, **one PostgreSQL**, no Redis required. Tune for **RAM ~1–2 GB** and low CPU.

## Process & pool

- **PM2 / systemd**: run **one** API instance first (`max_memory_restart` optional). Scale to 2 instances only if CPU stays &lt;70% and Postgres `max_connections` allows it.
- **Env** (see `.env.example`):
  - `PG_POOL_MAX=15`–`20` — total connections = instances × max.
  - `PG_STATEMENT_TIMEOUT_MS=25000` — after testing queries; prevents hung requests from holding connections.
  - `HTTP_SERVER_TIMEOUT_MS=120000` — already defaulted in `server.js`.

## Database

- Run migrations including **`030_booking_idempotency.sql`** (`npm run migrate` or `node run-030-migration.js`) so duplicate booking submits are safe.
- Indexes **023**, **025** already cover search/bookings; no extra daemons.

## API behaviour (this repo)

- **Trip search**: `limit` default **40**, max **80**; `offset` max **400** — protects DB from huge scans.
- **Bookings**: optional **`Idempotency-Key`** header / `idempotency_key` body — mobile sends automatically.
- **Trip details**: one combined `bookings` query instead of two.

## Nginx (if used)

- `proxy_read_timeout` / `proxy_connect_timeout` aligned with `HTTP_SERVER_TIMEOUT_MS`.
- `client_max_body_size` small unless you upload large files.

## What not to enable on KVM1

- Separate Redis + Bull queues **until** you actually need background jobs and have RAM.
- Multiple read replicas — not applicable on one VPS.

See also: `DATABASE_SCALING.md`.
