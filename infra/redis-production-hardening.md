# Redis production hardening (VPS)

The app code is already outage-resilient (fail-fast commands, fail-open rate
limiting, infinite reconnect). These two are **server-side** settings that the
code cannot apply itself — do them once on the VPS.

## 1. Cap memory + eviction (prevents OOM-kill → crash)

Without `maxmemory`, Redis can grow until the OS kills it. Rate-limit and
Socket.IO keys all carry TTLs, so LRU eviction is safe.

Edit `/etc/redis/redis.conf` (path may vary):

```
maxmemory 128mb
maxmemory-policy allkeys-lru
```

Then:

```bash
sudo systemctl restart redis-server
redis-cli config get maxmemory          # verify (should be 134217728)
redis-cli config get maxmemory-policy    # verify (allkeys-lru)
```

To apply without editing the file (until next restart):

```bash
redis-cli config set maxmemory 128mb
redis-cli config set maxmemory-policy allkeys-lru
```

## 2. Auto-restart on crash (self-healing)

The app reconnects forever, but the **Redis process** itself needs a supervisor.
With the official Debian/Ubuntu package it already runs under systemd — just
confirm the restart policy:

```bash
systemctl show redis-server -p Restart       # want: Restart=always (or on-failure)
```

If it is not `always`/`on-failure`, add a drop-in:

```bash
sudo systemctl edit redis-server
# paste:
# [Service]
# Restart=always
# RestartSec=2
sudo systemctl daemon-reload
sudo systemctl restart redis-server
```

## Notes

- Docker stack already has both (see
  `docker-compose-luharide-backend-microservices-redis-stack.yml`:
  `restart: unless-stopped` + `--maxmemory 128mb --maxmemory-policy allkeys-lru`).
- 128 MB is comfortable for rate-limit + socket adapter at current scale. The app
  alerts (Telegram) when used memory crosses `REDIS_MEM_WARN_MB` (default 80 MB),
  so you get warned before eviction pressure builds.
