# VPS deploy checklist (LuhaRide backend)

Yeh **order** follow karo. Hum yahan se tumhara server **touch nahi** kar sakte — tum SSH par ye commands chalao.

---

## 1) Server health (optional but recommended)

```bash
sudo apt update && sudo apt upgrade -y
# Jab maintenance ho: sudo reboot
```

Jab banner mein **“System restart required”** ho, reboot ke baad services dubara check karo.

---

## 2) Code & dependencies

```bash
cd /path/to/luharide   # jahan repo clone hai
git pull origin main
cd backend
npm install
```

---

## 3) `.env` (production) — Redis se pehle zaroori

`backend/.env` (copy from `.env.example`, **never commit**):

| Key | Value |
|-----|--------|
| `NODE_ENV` | `production` |
| `TRUST_PROXY` | `1` (nginx ke peeche) |
| `CLIENT_URL` | tumhara real app/API URL (`https://api.domain.com` ya jo Flutter use kare) |
| `DB_*` | PostgreSQL |
| `JWT_SECRET` | lamba random |
| `EMAIL_*` / SMTP | OTP ke liye |

Microservices mode: `AUTH_URL`, `CORE_URL`, … (defaults localhost) + `GATEWAY_PORT` — [`MICROSERVICES_RUN.md`](./MICROSERVICES_RUN.md).

---

## 4) Database migrations

```bash
cd backend
npm run migrate
```

Agar error aaye to DB credentials / PostgreSQL running check karo.

---

## 5) Process manager (PM2 example)

**Monolith:**

```bash
cd backend
pm2 start server.js --name luharide-api
pm2 save
pm2 startup   # reboot par auto (instructions follow karo)
```

**Microservices:** `ecosystem.microservices.config.cjs` — `pm2 start ecosystem.microservices.config.cjs`

---

## 6) Nginx + SSL (outline)

- Reverse proxy `https://` → `http://127.0.0.1:3000` (gateway ya monolith).
- `proxy_set_header X-Forwarded-For`, `X-Forwarded-Proto`, `Host`.
- Certbot (Let’s Encrypt) jab domain point ho.

---

## 7) Verify

```bash
curl -sS https://YOUR_DOMAIN/health
curl -sS https://YOUR_DOMAIN/api/health
```

App se: login + trip search/booking smoke test.

---

## 8) Redis (optional — scale / multi-instance)

```bash
sudo apt install -y redis-server
sudo systemctl enable --now redis-server
```

`backend/.env`:

```env
REDIS_ENABLED=true
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
```

Phir `pm2 restart all`. Detail: [`PHASE_REDIS_AND_OBSERVABILITY.md`](./PHASE_REDIS_AND_OBSERVABILITY.md).

---

## Gateway tracing note

Gateway **ab** upstream ko `X-Request-Id` forward karti hai (`gateway/server.js`). Purana deploy ho to `git pull` ke baad restart zaroori.
