# Flutter app — API base URL & Dio

**Gateway** exposes everything under **`/api/*`**.

## Client behavior

1. **`buildApiUrl(path)`** in `ApiService` concatenates `EnvConfig.apiBaseUrl` + path into a **single absolute URL** (e.g. `http://host:3000/api/simple-auth/login`).  
   Dio `baseUrl` is **`''`** so there is **no** merge ambiguity across Dio versions / platforms.

2. **`EnvConfig.apiBaseUrl` / `socketUrl`** are **getters** (not const):
   - **`API_BASE_URL`** / **`SOCKET_URL`** dart-define wins if set.
   - Else **`USE_LOCAL_API=true`** + **`kDebugMode`**: Web → **`127.0.0.1`** (Windows: `localhost` → IPv6 ::1 vs Node IPv4 mismatch), Android emulator → `10.0.2.2`, port from **`LOCAL_API_PORT`** (default **3000** monolith; **3010** for `npm run dev:stack`).
   - Else production VPS defaults.

3. Debug logs print **`options.uri`** so you can verify the exact URL in the console.

Share links use `ApiConstants.baseUrl` **without** trailing slash: `.../api/trips/...`.

## Local Web + local backend

**Monolith** (`cd backend && node server.js`) — port **3000**:

```bash
flutter run -d chrome --dart-define=USE_LOCAL_API=true
```

**Microservices** (`npm run dev:stack` in `backend`) — gateway port **3010** (not 3000):

```bash
flutter run -d chrome --dart-define=USE_LOCAL_API=true --dart-define=LOCAL_API_PORT=3010
```

Or explicit URL:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3010/api --dart-define=SOCKET_URL=http://localhost:3010
```

If login still returns **404**, check the printed **full URI** — then verify that URL returns 200 with `curl` or browser; the VPS may need redeploy or nginx/gateway routing.

## `XMLHttpRequest onError` / connection error (Chrome Web)

Often **not a Dio bug**. Check in order:

1. **Backend running + matching port** — open **`/health`** on the port you actually run (monolith **`http://localhost:3000/health`**, microservices gateway **`http://localhost:3010/health`**). `dev:stack` = **3010**; monolith = **3000**. Wrong port → `ERROR[null]`. Flutter: **`LOCAL_API_PORT=3010`** when using the stack.
2. **Use `localhost`, not `127.0.0.1`, for the API on Web** — avoids Chrome **Private Network Access** edge cases; **`USE_LOCAL_API` uses `localhost` on Web** (`EnvConfig`).
3. **Server headers** — `backend/src/middleware/corsLuha.js` sets **`Access-Control-Allow-Private-Network: true`** when needed and **`cors({ origin: true })`**. Restart Node after pull.
4. **Helmet CORP** — `backend/src/config/helmetConfig.js` uses **`crossOriginResourcePolicy: cross-origin`**.
5. **Listen address** — servers default to **`0.0.0.0`** (`LISTEN_HOST`) so Windows/WSL/Docker can reach the port.

Chrome **DevTools → Network** (failed / blocked) and **Console** for CORS / PNA messages.
