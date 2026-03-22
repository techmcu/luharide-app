# Database scaling (LuhaRide backend)

**Single basic VPS (Hostinger KVM1, ~1 GB RAM):** see **`KVM1_HOSTINGER.md`** for pool sizes, timeouts, and what to avoid.

## Connection pool (`backend/src/config/database.js`)

- **`PG_POOL_MIN` / `PG_POOL_MAX`**: Connections per **one** Node.js process. Default max is **20**.
- Raising `PG_POOL_MAX` helps only if PostgreSQL still has free `max_connections` and CPU/IO headroom. Formula:  
  `(PM2 instances × PG_POOL_MAX) + admin + migrations + other apps` must stay **below** Postgres `max_connections`.
- **`PG_STATEMENT_TIMEOUT_MS`**: Optional safety cap so runaway queries release the connection (set e.g. `30000` in production after testing).

## Read replica (optional)

- Set **`DB_READ_HOST`** to a host **different from `DB_HOST`** to open a second pool (`poolRead`) for read-heavy `SELECT`s (`queryRead` in code).
- **`PG_POOL_READ_MIN` / `PG_POOL_READ_MAX`**: Size of the read pool only.
- **Tradeoff**: Replica can lag slightly; list/search UIs usually tolerate sub-second staleness. Writes and transactions always use the primary pool.

## PgBouncer (recommended at scale)

Without a pooler, each app instance holds many real TCP connections to Postgres. **PgBouncer** in *transaction* mode multiplexes many app connections onto fewer DB connections. Typical setup: app → PgBouncer → Postgres; tune pool sizes and `max_connections` together.

## Single primary, no replica

All reads and writes hit one server. Under high concurrency, **Postgres** (CPU, locks, disk) or **Node** (event loop, pool wait) can become the bottleneck. Mitigations:

- Indexes and query tuning (EXPLAIN ANALYZE on hot paths).
- Cache read-heavy endpoints (Redis) where acceptable.
- Horizontal scaling: multiple API instances + load balancer (still watch total DB connections).

See also: `SOCKET_IO_REALTIME.md` for realtime vs DB load.
