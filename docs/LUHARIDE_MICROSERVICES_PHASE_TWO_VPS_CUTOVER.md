# Phase 2 — VPS cutover (monolith → gateway + 4 services)

Phase 1 local verify ho chuka ho to yahan se production par switch karo.

## Pehle confirm

| Check | Detail |
|--------|--------|
| Phase 1 | Local `npm run check:ms` sab **HTTP 200** |
| Code | `git push` ho chuka ho taaki VPS `git pull` se naya ecosystem + microservices mile |
| Nginx | Abhi bhi `proxy_pass` **port 3000** pe hai (monolith jaisa) — gateway bhi **3000** pe chalega |
| `.env` | VPS `backend/.env` pehle se DB / JWT / Razorpay wagairah — **same** rehta hai (har microservice + gateway `dotenv` load karta hai `backend/` se) |
| Ports | **3000** gateway, **3001–3004** internal — firewall se sirf **80/443** (aur SSH) khula rakho; 3001–3004 sirf localhost |

## Step-by-step (VPS — bash)

SSH se server par:

```bash
cd /var/www/luharide-backend/backend   # apna actual path
git pull origin main
npm install --production
npm run migrate
```

Monolith band karo (purana naam usually `luharide-api`):

```bash
pm2 stop luharide-api 2>/dev/null || true
pm2 delete luharide-api 2>/dev/null || true
```

Microservices + gateway start:

```bash
pm2 start pm2-ecosystem-luharide-api-gateway-and-microservices.config.cjs
pm2 save
pm2 startup   # pehli baar ho to jo command print ho use run karo (root/sudo)
```

Verify:

```bash
pm2 list
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3000/health
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3001/health
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3002/health
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3003/health
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:3004/health
```

Sab **200** hona chahiye. Phir browser / app se `https://api...` login + ek trip flow smoke test.

## PM2 process names (naya)

| Name | Role |
|------|------|
| `luharide-auth-service` | 3001 |
| `luharide-core-ride-service` | 3002 |
| `luharide-union-admin-service` | 3003 |
| `luharide-platform-admin-payments-service` | 3004 |
| `luharide-api-gateway` | 3000 |

## Nginx

Agar pehle monolith `127.0.0.1:3000` pe tha, **change zaroori nahi** — gateway bhi **3000** hai.

Naya sample: `infra/nginx-reverse-proxy-luharide-api-gateway.example.conf`

## Rollback (turant)

```bash
cd /var/www/luharide-backend/backend
pm2 delete all
pm2 start server.js --name luharide-api
pm2 save
```

## Optional script

Repo mein: `backend/scripts/vps-cutover-luharide-microservices.sh` — Linux VPS par `bash` se chalao (path edit karke).

## Phase 3+

Redis, observability: `PHASE_REDIS_AND_OBSERVABILITY.md`, `ARCHITECTURE_MICROSERVICES_ROADMAP.md`.
