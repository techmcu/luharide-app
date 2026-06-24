# LuhaRide - Online API Test Guide

## ✅ API Online Hai!

**Base URL:** http://76.13.243.157:3000

---

## Quick Check (Browser)

| URL | Expected |
|-----|----------|
| http://76.13.243.157:3000/health | `{"status":"ok","database":"connected"}` |
| http://76.13.243.157:3000/ | `{"message":"LuhaRide API","status":"running"}` |

---

## Test Script (Local)

```powershell
cd D:\cur\luharide\backend
node test-online-api.js
```

---

## Fixes Applied (Push + Deploy ke baad)

1. **Logout** – Ab invalid token ke saath bhi logout kaam karega
2. **Auth /me** – `bio` column missing hone par bhi chalega
3. **Signup** – `phone` VARCHAR(15) fix (email-only signup)
4. **Create-demo** – Same phone fix

---

## VPS pe Migrations (ek baar)

```bash
ssh root@76.13.243.157
cd /var/www/luharide-backend/backend
npm run migrate
pm2 restart luharide-api
```

---

## Mobile App Test

1. **Purana token clear karo** – App uninstall/reinstall ya Clear Data
2. **Signup** karo (naya email) → Login
3. Trips search – migrations ke baad kaam karega

---

## Test Credentials (create-demo ke baad)

- Passenger: `passenger@demo.com` / `demo123`
- Driver: `driver@demo.com` / `demo123`
- Admin: `admin@demo.com` / `demo123`
