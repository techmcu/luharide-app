# 429 / “Too many requests” — kyun aata hai, fix kaise karein

## Short answer

- **`429`** = server ne **rate limit** lagaya (express-rate-limit). Ye **server overload** ka official code nahi hai, lekin limit cross hone par same status milta hai.
- **“Kabhi hota hai kabhi nahi”** aksar isliye:
  1. **Global limit**: Har IP ko **15 minute** mein maximum **N** API calls (`/api/*` sab count — search, trips, login, profile…).
  2. **Nginx / reverse proxy** ke peeche **`TRUST_PROXY=1` na ho** → saari duniya ko **ek hi IP** dikhai deta hai → **saare users mil kar ek hi 500/100 bucket** use karte hain → jaldi **429**.
  3. App mein **bahut saari requests** (typing par suggestions, refresh, double tap) → limit jaldi full.

## Server par kya karna hai

1. **Nginx use karte ho to** `.env` mein:
   ```env
   TRUST_PROXY=1
   ```
   Phir Node ko restart karo. Taaki har user ka **asli IP** (`X-Forwarded-For`) count ho.

2. **Limit badhana** (optional):
   ```env
   API_RATE_LIMIT_MAX=500
   API_RATE_LIMIT_WINDOW_MS=900000
   ```
   Default ab code mein **500 / 15 min** hai (pehle 100 tha).

3. Health check ko limit se pehle hi skip hai — theek hai.

## App side

- Login par **“No token found”** debug log **normal** hai — login pe token hota hi nahi; ab debug mein ye spam kam kiya gaya hai.
- **429** par user ko **clear message** dikhane ke liye Dio interceptor + login error handling update hai.

## Polling / load kam kaise rakhein

- **Har second API** mat chalao — search suggestions ke liye **debounce** (already ~350ms) use karo.
- List screens par **sirf pull-to-refresh** + **socket** (agar use ho) — blind `Timer.periodic` se poora API mat poll karo.
- **Double submit** rokho: button pe loading state, duplicate POST na jaye.
