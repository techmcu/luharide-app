# LuhaRide – API Setup Guide (A to Z)

## 📌 Simple Summary

| Environment | API URL | Kab use karein |
|-------------|---------|----------------|
| **Local (PC pe test)** | `http://localhost:3000/api` | Jab backend PC pe chal raha ho |
| **Live (VPS)** | `http://76.13.243.157:3000/api` | Production app ke liye |

---

## 🏗️ Architecture – Kaise Kaam Karta Hai

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Mobile App     │────▶│  API Server  │────▶│  PostgreSQL DB   │
│  (Flutter)      │     │  (Node.js)    │     │  (Database)      │
└─────────────────┘     └──────────────┘     └─────────────────┘
        │                        │
        │                        │
        ▼                        ▼
   API calls:              Hostinger VPS
   Login, Trips,            http://76.13.243.157:3000
   Bookings, etc.
```

---

## 📁 Files Jahan API URL Set Hoti Hai

### 1. `mobile/lib/core/config/env_config.dart`
- **apiBaseUrl** – API ke liye (login, trips, bookings, etc.)
- **socketUrl** – Real-time updates ke liye (Socket.IO)

### 2. `mobile/lib/core/constants/api_constants.dart`
- **baseUrl** – Share URL ke liye (e.g. trip share link)

### 3. Kahan se use hota hai?
- `ApiService` uses `EnvConfig.apiBaseUrl` as base URL
- All API calls: `/auth/login`, `/trips/search`, `/bookings` etc. automatically add base URL ke saath

---

## 🔄 Local vs Live – Kya Change Karna Padta Hai

### Local Development (PC pe test)

```
env_config.dart:
  apiBaseUrl = 'http://localhost:3000/api'   // ya 10.0.2.2:3000 (Android emulator)
  socketUrl = 'http://localhost:3000'

api_constants.dart:
  baseUrl = 'http://localhost:3000/api'
```

### Live Production (VPS)

```
env_config.dart:
  apiBaseUrl = 'http://76.13.243.157:3000/api'
  socketUrl = 'http://76.13.243.157:3000'

api_constants.dart:
  baseUrl = 'http://76.13.243.157:3000/api'
```

---

## 📡 API Examples

| Action | API Endpoint | Full URL |
|--------|--------------|----------|
| Login | `/auth/send-otp` | `http://76.13.243.157:3000/api/auth/send-otp` |
| Search Trips | `/trips/search` | `http://76.13.243.157:3000/api/trips/search` |
| Create Booking | `/bookings` | `http://76.13.243.157:3000/api/bookings` |
| Health Check | `/health` | `http://76.13.243.157:3000/health` |

---

## 🔗 GitHub se Connection – Kaise Kaam Karta Hai

```
┌──────────────┐     git push      ┌──────────────┐     git pull      ┌──────────────┐
│  Your PC     │ ───────────────▶  │   GitHub     │ ◀───────────────  │  VPS Server  │
│  (Code)      │                   │  (Repository)│                   │  (Deploy)     │
└──────────────┘                   └──────────────┘                   └──────────────┘
```

### Flow:

1. **Tum PC pe code likhte ho** → `git add`, `git commit`, `git push`
2. **GitHub** pe code save ho jata hai
3. **Deploy script** (`deploy-to-vps.ps1`) VPS pe `git pull` karta hai
4. **VPS** pe latest code aa jata hai
5. **PM2** server restart karta hai (auto)

### Commands:

```bash
# PC pe code change karne ke baad
git add .
git commit -m "your message"
git push origin main

# VPS pe deploy (deploy script)
.\deploy-to-vps.ps1
```

---

## ✅ Abhi Kya Set Hai (Live)

- **apiBaseUrl:** `http://76.13.243.157:3000/api`
- **socketUrl:** `http://76.13.243.157:3000`
- **baseUrl:** `http://76.13.243.157:3000/api`

---

## 🔄 Future: URL Change Karna Ho To

1. `mobile/lib/core/config/env_config.dart` kholo
2. `apiBaseUrl` aur `socketUrl` update karo
3. `mobile/lib/core/constants/api_constants.dart` mein `baseUrl` update karo
4. `git push` karo
5. App rebuild karo (flutter run / build)
