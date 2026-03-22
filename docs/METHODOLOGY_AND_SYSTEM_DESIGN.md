# LuhaRide — Methodology, references & system design

Yeh doc tumhe **samajhne ke liye** hai: hum **kaunsa approach** use kar rahe hain, **kis type ke platforms** se concept milta hai, aur **microservices / system design rules** yahan kaise apply hote hain — **bina marketing jargon ke**.

---

## 1) Overall methodology (hum kya follow kar rahe hain)

| Idea | LuhaRide mein kaise |
|------|---------------------|
| **Iterative delivery** | Pehle working product (monolith), phir scale / split jab zaroorat ho |
| **Strangler Fig pattern** | Purana `server.js` chalta rahe; naya traffic **API Gateway** se 4 services pe ja sakta hai — dheere-dheere migrate |
| **Pragmatic microservices** | **4 bounded contexts** + **1 gateway** — textbook “pure” DB-per-service abhi nahi, kyunki cost zyada, team chhoti |
| **Single mobile contract** | Flutter **hamesha same REST paths** (`/api/...`) — chahe neeche monolith ho ya gateway+services |

**Reference (samajhne ke liye, copy nahi):**

- **Ride / mobility apps** (Uber, Ola, Grab, BlaBlaCar): shuruat mein **monolith backend** + relational DB common hai; baad mein search, maps, payments alag scale hote hain.
- **API Gateway pattern**: AWS API Gateway, Kong, Netflix (Zuul-era) — **ek public entry**, andar services. Hamara `gateway/server.js` yahi **idea** follow karta hai (reverse proxy + Socket.IO).
- **“Modular monolith” phir split**: Shopify, GitHub ne bhi **pehle ek repo / strong modules**, phir services — **Martin Fowler** style “don’t start with microservices if you don’t need them”.

---

## 2) Tumhara stack = kis “shape” ka design

```
Flutter (mobile)
       │
       ▼
┌──────────────────┐
│   API Gateway    │  ← port 3000, CORS, rate limit, Socket.IO
│  (single URL)    │
└────────┬─────────┘
         │ HTTP proxy by path
    ┌────┴────┬─────────┬──────────┐
    ▼         ▼         ▼          ▼
 Auth     Core      Union    Platform
 :3001    :3002     :3003    :3004
    └────────┴─────────┴──────────┘
              │
              ▼
        PostgreSQL (shared)
```

**System design principles yahan:**

| Principle | Status |
|-----------|--------|
| **Single entry for clients** | Gateway — mobile ko multiple URLs nahi dene padte |
| **Stateless HTTP APIs** | JWT / headers; session server-side optional |
| **Separation of concerns** | `routes` → `controllers` → `repositories` / `services` (`backend/src`) |
| **Failure isolation** | Services alag process — ek crash = sirf uska risk (**shared DB** abhi boundary ko soft karti hai) |
| **Observability** (ideal next step) | Har service ke liye **structured logs**, baad mein tracing (OpenTelemetry) |

---

## 3) Microservices “rules” — kya follow ho raha hai

Industry mein common checklist (samajh lo, har jagah 100% nahi hota):

| Rule | Ideal | LuhaRide abhi |
|------|--------|----------------|
| **Bounded context** | Har service ka clear domain | Haan — Auth / Core / Union / Platform |
| **Independent deploy** | Alag PM2 / Docker container | Haan — `ecosystem.microservices.config.cjs`, compose |
| **Database per service** | Alag DB ya schema owner | **Abhi shared PostgreSQL** — pragmatic; baad mein split |
| **No shared library mess** | Kam coupling | Code **shared** `src/` se — **trade-off**: velocity vs purity |
| **API Gateway** | Ek public face | Haan — `gateway/server.js` |
| **Async for cross-domain** | Events / queue | Partial — future: Redis/Bull for notifications |

**Seedha matlab:** Tum **microservices direction** mein ho, lekin **“textbook pure”** (har service ka alag DB, zero shared code) **abhi nahi** — ye **conscious choice** hai taaki product fast iterate ho sake.

---

## 4) Code structure (well-organized kahan hai)

```
backend/
├── server.js                 # Monolith mode (all-in-one; VPS simple)
├── gateway/server.js       # Microservices mode entry
├── microservices/
│   ├── sharedApp.js        # Common middleware, health, errors
│   ├── authService.js
│   ├── coreService.js
│   ├── unionService.js
│   └── platformService.js
└── src/
    ├── config/             # env, db, logger
    ├── middleware/         # auth, rate limits, validation
    ├── routes/             # HTTP surface
    ├── controllers/        # request/response orchestration
    ├── services/           # business helpers (email, token, OTP)
    ├── repositories/       # DB access (queries)
    └── socket/             # realtime
```

**Logical flow:** `route` → `controller` → `service/repository` → DB.  
Ye **layered architecture** — system design mein standard pattern.

---

## 5) Kab monolith, kab microservices stack

| Scenario | Use |
|----------|-----|
| Local debug / chhota VPS | `node server.js` |
| Alag scale / team ownership chahiye | `npm run dev:stack` ya Docker / PM2 microservices |
| Production pehli baar | Monolith bhi **theek**; same codebase |

---

## 6) Aage “proper” banane ke liye (priority order)

1. **Metrics + logs** — har request `service` name tag (gateway vs auth vs core)  
2. **Redis** — rate limit store + Socket.IO adapter (multi-instance)  
3. **Queues** — email/SMS worker (Core/API block na kare)  
4. **DB ownership** — pehle **schema** alag, phir DB alag (agar zaroorat ho)

---

## 7) Short summary (ek minute mein)

- **Method:** Industry-style **iterative** + **gateway-based microservices** + optional **monolith** — **Strangler** friendly.  
- **Reference mindset:** Ride apps + API Gateway pattern + modular-then-split — **LuhaRide-specific** domain (union, Uttarakhand trips).  
- **Microservices:** **4 services + gateway** implement hai; **shared DB** = practical step, **pure rules** poori tab jab team/infra ready ho.  
- **Code:** **Layered `src/`** + **thin microservice boot files** — maintainable structure.

---

*Related: [`ARCHITECTURE_MICROSERVICES_ROADMAP.md`](./ARCHITECTURE_MICROSERVICES_ROADMAP.md), [`MICROSERVICES_RUN.md`](./MICROSERVICES_RUN.md)*
