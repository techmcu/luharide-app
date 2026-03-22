# Phase next — Redis + observability (implemented)

## 1) Optional Redis (`REDIS_ENABLED=true`)

| Feature | Without Redis | With Redis |
|---------|---------------|------------|
| `express-rate-limit` | In-memory per **Node process** | Shared across **all** processes / replicas |
| Socket.IO | Single Node only sees its own rooms | **`@socket.io/redis-adapter`** — broadcast across multiple gateway/monolith instances |

**Env:** `backend/.env.example` — `REDIS_ENABLED`, `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`.

**Docker microservices:** `infra/docker-compose.microservices.yml` includes `redis:7-alpine` and sets `REDIS_ENABLED=true` + `REDIS_HOST=redis` for all app containers.

**Local:** Install Redis (Windows: WSL/Docker), then `REDIS_ENABLED=true` in `.env`.

---

## 2) Request correlation

- Middleware: `src/middleware/requestContext.js`
- Header: `X-Request-Id` (echoed on response); accepts incoming `X-Request-Id` / `X-Correlation-Id`
- **Gateway** forwards `X-Request-Id` to upstream services (`on.proxyReq`)

---

## 3) Service name in logs

- Env: `LUHA_SERVICE_NAME` (optional)
- Defaults: `luha-monolith`, `luha-gateway`, `luha-ms-auth`, `luha-ms-core`, `luha-ms-union`, `luha-ms-platform`
- Winston `defaultMeta.service` — filter logs per service in Loki/Datadog later

---

## 4) Error logs

- `errorHandler` includes `requestId: req.id` on warn/error log lines

---

## Next (not in this phase)

- OpenTelemetry / distributed tracing
- Bull/BullMQ for email/SMS off-request path
- k6 load tests in CI

---

*Code: `src/config/redis.js`, `src/socket/socketRedisAdapter.js`, `src/middleware/rateLimiter.js` (Redis store), `gateway/server.js`, `server.js`.*
