# LuhaRide — microservices migration (step-by-step, meaningful file names)

**Stack:** Node.js + Express, PostgreSQL, Socket.IO, Flutter, optional Redis, PM2, Nginx.

Pure **100%** microservices = long journey. Yeh document **Phase 0 → 8** + **artifacts list** hai.

**Current status + radius verdict + next steps:** [`LUHARIDE_MICROSERVICES_STATUS_AND_NEXT_STEPS.md`](./LUHARIDE_MICROSERVICES_STATUS_AND_NEXT_STEPS.md)

---

## Meaningful names — repo artifacts (A→Z)

| Purpose | Path / command |
|---------|----------------|
| Step-by-step migration (this file) | `docs/LUHARIDE_MICROSERVICES_MIGRATION_STEP_BY_STEP.md` |
| Phase 1 done? (repo vs your machine) | `docs/LUHARIDE_MICROSERVICES_PHASE_ONE_IMPLEMENTATION_STATUS.md` |
| How to run gateway + 4 services locally | `docs/MICROSERVICES_RUN.md` |
| PM2: 5 processes, gateway last | `backend/pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs` |
| Health check script | `backend/scripts/verify-luharide-microservices-health-endpoints.js` |
| Docker: gateway + services + Redis | `infra/docker-compose-luharide-backend-microservices-redis-stack.yml` |
| Nginx example → port 3000 | `infra/nginx-reverse-proxy-luharide-api-gateway.example.conf` |
| Start all 5 Node apps locally | `npm run develop:luharide-microservices-local-five-services` (alias: `npm run dev:stack`) |
| Verify all `/health` | `npm run verify:luharide-microservices-health-endpoints` (alias: `npm run check:ms`) |

---

## Phase overview

| Phase | Goal | ~“Pure” |
|-------|------|---------|
| **0** | Preconditions | — |
| **1** | Local five services + health verification | ~25% |
| **2** | VPS PM2 + Nginx | ~40% |
| **3** | Redis | ~45% |
| **4** | Module boundaries in `src/` | ~55% |
| **5** | Bull/BullMQ | ~65% |
| **6** | Read replica | ~70% |
| **7** | Schema per service | ~85% |
| **8** | DB per service | ~95–100% |

---

## Phase 0 — Preconditions

- [ ] `backend/.env` complete (see `backend/.env.example`)
- [ ] `npm run migrate`
- [ ] Flutter `API_BASE_URL` points to gateway when testing microservices mode

---

## Phase 1 — Local verify

**Terminal A**

```bash
cd backend
npm install
npm run develop:luharide-microservices-local-five-services
```

**Terminal B** (after ~5 seconds)

```bash
cd backend
npm run verify:luharide-microservices-health-endpoints
```

**Pass:** exit code `0`, every line `OK`.

**Optional:** browser `http://localhost:3010/health`, `http://localhost:3010/api/health` (dev stack uses **3010**; monolith stays free on **3000**).

**Phase 1 complete** = verification script passes **on your machine** + optional API smoke test.  
Repo-side work is tracked in `LUHARIDE_MICROSERVICES_PHASE_ONE_IMPLEMENTATION_STATUS.md`.

---

## Phase 2 — VPS (monolith → five processes)

**Full checklist:** `LUHARIDE_MICROSERVICES_PHASE_TWO_VPS_CUTOVER.md`  
**Optional one-shot (Linux VPS):** `backend/scripts/vps-cutover-luharide-microservices.sh`

```bash
cd /var/www/.../backend
git pull && npm install && npm run migrate
pm2 stop luharide-api && pm2 delete luharide-api
pm2 start pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs
pm2 save
```

Nginx sample: `infra/nginx-reverse-proxy-luharide-api-gateway.example.conf`

**Breaking (PM2):** Purana file `ecosystem.microservices.config.cjs` hata diya — ab sirf `pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs` use karo. PM2 **process names** bhi lambe / descriptive ho gaye (`luharide-api-gateway`, etc.).

**Rollback:** `pm2 delete all` → `pm2 start server.js --name luharide-api`

---

## Phase 3+

`PHASE_REDIS_AND_OBSERVABILITY.md`, `ARCHITECTURE_MICROSERVICES_ROADMAP.md`, `VPS_DEPLOY_CHECKLIST.md`.

---

## Docker (optional)

```bash
docker compose -f infra/docker-compose-luharide-backend-microservices-redis-stack.yml up --build
```
