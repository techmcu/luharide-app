# TRUST_PROXY + Nginx — A to Z (LuhaRide)

**Hinglish guide:** yeh kya hai, kyun, kab zaroori, fayda, kaise lagayein.

---

## A) Problem kya hai? (bina samjhe mat skip karo)

1. User ka phone → internet → **Nginx** (443) → **Node gateway** (127.0.0.1:3000).

2. Jab request Node tak aati hai, TCP connection **Nginx se** aati hai.  
   Bina setting ke Node ko lagta hai har request **ek hi client** se aa rahi hai = **Nginx / server ki IP** (ya `127.0.0.1`).

3. Tumhare app mein **rate limit** hai (`express-rate-limit`):  
   default **~500 requests / 15 min per “IP”** (`backend/src/middleware/rateLimiter.js`).

4. Agar har user ko **same IP** dikhe → **saare users mil kar ek hi 500 bucket** use karenge →  
   thodi si bheed mein logon ko **429 Too Many Requests** aa sakta hai — **galti se sab block** jaisa feel.

**Isi problem ka fix:** Node ko bolo “peeche **trusted proxy** (Nginx) hai; **Asli user IP** header se lo.”  
Woh setting Express mein **`trust proxy`** ke naam se hai; tumhari repo mein **`.env`** se: **`TRUST_PROXY=1`**.

---

## B) `TRUST_PROXY=1` actually kya karta hai?

- **`backend/src/config/trustProxy.js`** — sab jagah same parsing (`1`, `true`, `yes`, `on`, `2`…`32` hops, `0` = off).
- **`backend/gateway/server.js`**, monolith **`server.js`**, microservices **`sharedApp.js`** → `applyTrustProxy(app)`.
- **PM2 production ecosystem** → default **`TRUST_PROXY=1`** har process par (`.env` se override; dotenv existing env overwrite nahi karta — PM2 env pehle aata hai).
- Gateway **proxy** upstream ko **`X-Forwarded-For` / `X-Real-IP`** forward karta hai taaki auth/core par **per-user** limit kaam kare.

  ```text
  TRUST_PROXY=1  →  app.set('trust proxy', 1)
  ```

- Iske baad Express **`X-Forwarded-For`** / **`X-Real-IP`** ko use karke **`req.ip`** = **real user** jaisa treat karta hai (jab sahi proxy headers aayein).

- **Rate limit** har **alag user IP** par alag count karta hai — **fair**.

---

## C) Fayda tumhe kya?

| Fayda | Explanation |
|--------|-------------|
| **Har user alag limit** | 100 log app chalaen to sab **ek bucket** mein nahi ghusenge. |
| **Kam 429** | Normal use par “Too many requests” kam aayega. |
| **Logs / security** | Kabhi-kabhi logs mein sahi client IP dikhna useful hota hai. |

Yeh **feature add nahi** karta — sirf **existing rate limit ko sahi IP pe** lagata hai.

---

## D) Kab **zaroori**, kab **optional**?

| Setup | TRUST_PROXY |
|--------|-------------|
| API **`https://api.domain.com`** → **Nginx** → Node | **Rakhna chahiye `1`** |
| **Cloudflare** / load balancer same pattern | **Rakhna chahiye `1`** |
| Seedha **`http://IP:3000`** app se, **Nginx skip** | **Zaroori nahi** — har client direct alag connection (mostly alag IP) |
| Sirf **localhost** dev | Aksar **off** theek |

---

## E) Nginx side — kya hona chahiye?

Real IP tabhi aayega jab **Nginx headers bheje**. Tumhare example mein already hai:

**`infra/nginx-reverse-proxy-luharide-api-gateway.example.conf`:**

```nginx
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

Agar tumhara config **in lines ke bina** hai → pehle **Nginx theek** karo, phir `TRUST_PROXY=1`.

---

## F) VPS par step-by-step (kya karna hai)

### 1) File kholo

```bash
cd /var/www/luharide-backend/backend   # apna path
nano .env
```

### 2) Line add / edit karo

```env
TRUST_PROXY=1
```

(`true` bhi chal sakta hai — repo mein `1` ya `true` dono support.)

### 3) PM2 restart (taaki naya env load ho)

**Microservices mode:**

```bash
pm2 restart all
```

Ya sirf gateway:

```bash
pm2 restart luharide-api-gateway
```

*(Har service jo `sharedApp` / same `.env` use kare — agar rate limit un par bhi ho to `restart all` safe.)*

### 4) Verify (optional)

- App se normal use — **429** pehle se kam aana chahiye bheed mein.  
- Ya logs mein `req.ip` / morgan lines check (advanced).

---

## G) Security note (chhota lekin important)

- **`trust proxy`** sirf tab safe jab **client seedha internet se Node ko hit na kar raha ho** —  
  matlab peeche **sirf tumhara Nginx** ho jo headers set kare.

- Agar Node **public 3000** par bina firewall expose ho **aur** `TRUST_PROXY=1` ho →  
  attacker **fake `X-Forwarded-For`** bhej sakta hai (edge case).  
  **Best practice:** production mein **sirf Nginx 443** public; **3000 sirf localhost**.

---

## H) Related docs / code

| Item | Path |
|------|------|
| Rate limit detail | `backend/docs/RATE_LIMIT_429.md` |
| `.env` example | `backend/.env.example` (`TRUST_PROXY=1`) |
| Gateway | `backend/gateway/server.js` |

---

## I) One-line yaad rakho

**Nginx/HTTPS ke peeche ho → `.env` mein `TRUST_PROXY=1` + Nginx `X-Forwarded-For` → rate limit har user ki IP pe; fayda = fair limits, kam 429.**  
**Seedha IP:3000** → optional.
