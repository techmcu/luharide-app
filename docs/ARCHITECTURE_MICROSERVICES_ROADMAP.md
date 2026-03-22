# LuhaRide: Monolith → Scalable architecture (roadmap)

## Implemented in repo (4 services + gateway)

| Piece | File | Role |
|-------|------|------|
| API Gateway | `backend/gateway/server.js` | Port 3000, proxies `/api/*`, Socket.IO, `/uploads`, global rate limit |
| Auth | `backend/microservices/authService.js` | `/api/auth`, `/api/simple-auth` → 3001 |
| Core | `backend/microservices/coreService.js` | Trips, bookings, drivers, verification, cron jobs → 3002 |
| Union | `backend/microservices/unionService.js` | `/api/union` → 3003 |
| Platform | `backend/microservices/platformService.js` | Admin, payments, notifications, reviews, uploads → 3004 |

- **Run:** [`docs/MICROSERVICES_RUN.md`](./MICROSERVICES_RUN.md) — `npm run dev:stack`, Docker, PM2 (`ecosystem.microservices.config.cjs`).
- **Data:** Abhi **ek PostgreSQL** shared (practical step; DB-per-service baad mein).

---

**Seedha point:** Microservices = alag-alag **deploy** hone wale services + alag **data ownership** + **network** pe baat (HTTP/events). Isse throughput badh sakti hai, lekin **complexity, cost, aur bugs** bhi badhte hain. Chhote/medium product ke liye aksar **pehle monolith ko strong** karna zyada sahi hota hai.

**Abhi tumhara stack:** ek Express `server.js` + PostgreSQL + Socket.IO + cron jobs — ye **monolith** hai. Ye **galat nahi**; Instagram/Shopify jaisi teams ne bhi shuruat monolith se ki.

---

## 1) Kab microservices worth hai?

| Situation | Suggestion |
|-----------|------------|
| 1 team, 1 VPS, product-market fit dhundh rahe ho | **Modular monolith** + DB indexes + horizontal scale (2–4 Node processes) |
| Ek module CPU-heavy / alag release cycle (e.g. payments, maps) | **Pehle usko extract** karo |
| Multiple teams, clear ownership, SRE/monitoring ready | **Phir** full microservices socho |

**DSA / “best”:** Microservices ka core **graphs/trees** nahi — **boundaries, idempotency, eventual consistency, retries, observability** hai.

---

## 2) LuhaRide ke liye suggested service boundaries (future)

Tumhare `backend/src` routes se derive kiye gaye **logical** services (har ka apna DB schema ya DB — baad mein split):

| Service | Responsibility | Current routes / areas |
|---------|----------------|-------------------------|
| **Identity & Auth** | Login, signup, JWT, OTP, sessions | `simpleAuth`, `auth`, `tokenService` |
| **User / Profile** | Driver verification, documents | `driverVerification`, uploads |
| **Trip & Search** | Trips CRUD, search, seat layout | `trips`, `tripController` |
| **Booking** | Reservations, seat holds, conflicts | `bookings`, `bookingRepository` |
| **Union / Admin** | Union admin, policies, posters | `union`, `admin` |
| **Payments** | Razorpay webhooks, idempotent ledger | `payments` |
| **Notifications** | Email/SMS/push, templates | `notifications`, `emailService`, jobs |
| **Realtime** | Socket.IO rooms, trip updates | `socket/*` (often **alag process** pe rakho) |
| **Reviews** | Ratings | `reviews` |

**Note:** Abhi sab **ek PostgreSQL** share karte ho. Microservices mein ya to **database per service** (hard, migration heavy) ya **schema per service same DB** (compromise) — dono ke trade-offs alag hain.

---

## 3) Recommended migration (strangler pattern) — practical order

### Phase A — Monolith ko “scale-ready” (1–2 weeks effort)
- [ ] Load test (k6/Locust) on `/health`, login, trip list, booking
- [ ] DB: slow queries, **indexes**, `EXPLAIN ANALYZE`
- [ ] PM2 **cluster** ya multiple instances + nginx **sticky** for Socket.IO
- [ ] Redis: sessions / rate limit / **Socket.IO adapter** (multi-instance ke liye)
- [ ] Read replica sirf tab jab read-heavy proof ho

### Phase B — Modular monolith (code structure, same deploy)
- [ ] Folders by domain: `modules/auth`, `modules/trips`, `modules/bookings` …
- [ ] **No cross-imports** across modules except through clear “facade” or events
- [ ] Shared: `db pool`, `logger`, `config` only

### Phase C — Pehla alag service (choose ONE)
- **Realtime Gateway** (Socket.IO only) — sabse common pehla split  
  OR  
- **Notification worker** (queue consumer: Bull/BullMQ + Redis) — email/SMS off main thread

### Phase D — API Gateway + services
- Kong / nginx / Traefik as gateway
- Internal network, service-to-service auth (mTLS or signed JWT)
- **Distributed tracing** (OpenTelemetry), central logs

---

## 4) “1000 users ek saath” — microservices zaroori nahi

- **1000 concurrent lightweight API users** — achha VPS + tuned pool + **horizontal Node** + Redis socket adapter se **monolith se bhi** possible hai.
- **1000 heavy writes same second** — yahan **DB** aur **queue** matter karte hain, service count kam.

---

## 5) Kya avoid karo (early stage)

- 8 microservices + 8 repos + Kubernetes **bina** monitoring team  
- Distributed transactions (2PC) — prefer **sagas** + idempotent APIs  
- Shared mutable DB tables across “services” without clear owner  

---

## 6) Summary

| Question | Answer |
|----------|--------|
| Kya ab microservices ho chuka? | **Nahi** — abhi **monolith** hai. |
| Kya convert karna chahiye? | **Phase-wise**; pehle **scale + modular monolith**. |
| “Best se best” ek din mein? | **Nahi** — architecture **evolve** hoti hai; yeh doc **map** hai. |

**Next concrete step:** Phase A checklist run karo; jab metrics dikha dein ki **ek bottleneck** clear hai (e.g. notifications blocking API), tab **Phase C** mein wahi extract karo.

---

*File: safe to commit — no secrets.*
