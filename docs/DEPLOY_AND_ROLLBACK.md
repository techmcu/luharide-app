# Deploy, Monitoring, and Rollback

## What is now automated

- GitHub Actions runs quality gates before deploy:
  - Backend dependency install + JS syntax checks
  - Mobile `flutter analyze` + `flutter test`
- Deploy happens only when both gates pass.
- After deploy, workflow checks:
  - `GET /health`
  - `GET /api/health`
- If health checks fail, workflow triggers automatic rollback to previous commit via git reflog and reloads PM2 ecosystem.

## Payment feature toggle

- Online payment is disabled by default via:
  - `PAYMENTS_ENABLED=false`
- When disabled, `/api/payments/*` returns:
  - `503 PAYMENTS_DISABLED`
  - Message: offline payment to driver.

## Runtime monitoring endpoints

- Monolith mode:
  - `GET /health/metrics`
- Gateway mode:
  - `GET /health/metrics`

Metrics include:
- request counts
- 2xx/4xx/5xx split
- 5xx error rate %
- p50/p95/p99 latency (in-memory window)
- process memory
- CPU load average
- PostgreSQL pool stats (total/idle/waiting)

## Recommended alert thresholds

- `error_rate_5xx_pct > 2` for 5 minutes
- `latency_ms.p95 > 1200` for 5 minutes
- `db_pool.waiting > 10` sustained
- memory RSS continuously rising without recovery

## Manual rollback (if ever needed)

On VPS:

1. `cd /var/www/luharide-backend`
2. `git reflog -n 5`
3. Pick previous stable commit hash
4. `git reset --hard <hash>`
5. `cd backend`
6. `npm ci`
7. `pm2 startOrReload pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs --update-env`
8. `pm2 save`
