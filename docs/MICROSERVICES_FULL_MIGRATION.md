# LuhaRide → full microservices (step-by-step)

**Stack:** Node.js + Express, PostgreSQL, Socket.IO, Flutter, optional Redis, PM2, Nginx.

**100% pure** microservices = months-long migration. Is doc mein **Phase 0–8** hain.

---

## Phase overview

| Phase | Goal | ~“Pure” |
|-------|------|---------|
| **0** | Preconditions (`.env`, migrate, Flutter URL) | — |
| **1** | Local: `dev:stack` + health script ✅ | ~25% |
| **2** | VPS: PM2 ecosystem + Nginx → :3000 | ~40% |
| **3** | Redis (rate limit + Socket multi-node) | ~45% |
| **4** | Strict module boundaries in `src/` | ~55% |
| **5** | Bull/BullMQ async jobs | ~65% |
| **6** | PG read replica | ~70% |
| **7** | Schema-per-service (same Postgres) | ~85% |
| **8** | Database-per-service + sagas | ~95–100% |

---

## Phase 0 — Preconditions

- [ ] `backend/.env` from `.env.example` (secrets filled)
- [ ] `npm run migrate`
- [ ] Flutter `API_BASE_URL` = gateway URL when testing microservices

---

## Phase 1 — Local verify (START HERE)

**1)** Terminal A — stack chalao:

```bash
cd backend
npm install
npm run dev:stack
```

Ruko jab saari lines “listening” dikha dein (~2–5s).

**2)** Terminal B — health:

```bash
cd backend
npm run check:ms
```

**Pass:** har line `OK ... → 200`. **Fail:** koi service down / DB — `dev:stack` logs dekho.

**3)** Optional: browser / Postman

- `http://localhost:3000/health`
- `http://localhost:3000/api/health`
- Login flow app se (device → machine IP agar emulator ho)

**Exit criteria:** Phase 1 complete jab `check:ms` **exit 0** + basic API gateway se chale.

---

## Phase 2 — VPS (monolith → microservices)

```bash
cd /var/www/.../backend
git pull && npm install && npm run migrate
pm2 stop luharide-api && pm2 delete luharide-api
pm2 start ecosystem.microservices.config.cjs
pm2 save
```

Nginx sample: `infra/nginx.gateway.example.conf`

**Rollback:** `pm2 delete all` → `pm2 start server.js --name luharide-api`

---

## Phase 3+

See `PHASE_REDIS_AND_OBSERVABILITY.md`, `ARCHITECTURE_MICROSERVICES_ROADMAP.md`, `VPS_DEPLOY_CHECKLIST.md`.

---

*Gateway starts **last** in `ecosystem.microservices.config.cjs` so 3001–3004 pehle ready hon.*
