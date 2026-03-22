# Flutter app — API base URL & Dio

**Gateway** exposes everything under **`/api/*`**.

## Client behavior

1. **`buildApiUrl(path)`** in `ApiService` concatenates `EnvConfig.apiBaseUrl` + path into a **single absolute URL** (e.g. `http://host:3000/api/simple-auth/login`).  
   Dio `baseUrl` is **`''`** so there is **no** merge ambiguity across Dio versions / platforms.

2. **`EnvConfig.apiBaseUrl` / `socketUrl`** are **getters** (not const):
   - **`API_BASE_URL`** / **`SOCKET_URL`** dart-define wins if set.
   - Else **`USE_LOCAL_API=true`** + **`kDebugMode`**: Web → `127.0.0.1`, Android emulator → `10.0.2.2`.
   - Else production VPS defaults.

3. Debug logs print **`options.uri`** so you can verify the exact URL in the console.

Share links use `ApiConstants.baseUrl` **without** trailing slash: `.../api/trips/...`.

## Local Web + local backend

```bash
flutter run -d chrome --dart-define=USE_LOCAL_API=true
```

Or explicit:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:3000/api --dart-define=SOCKET_URL=http://127.0.0.1:3000
```

If login still returns **404**, check the printed **full URI** — then verify that URL returns 200 with `curl` or browser; the VPS may need redeploy or nginx/gateway routing.

## `XMLHttpRequest onError` / connection error (Chrome Web)

Often **not a Dio bug**. Check in order:

1. **Backend running** — `http://localhost:3000/health` must open in the same browser.
2. **Use `localhost`, not `127.0.0.1`, for the API on Web** — Flutter dev server is `http://localhost:<port>`. Calling `http://127.0.0.1:3000` triggers Chrome **Private Network Access**; without the right preflight headers the request fails with no status. **`USE_LOCAL_API` now uses `localhost` on Web** (`EnvConfig`).
3. **Server headers** — `backend/src/middleware/corsLuha.js` sets **`Access-Control-Allow-Private-Network: true`** when needed and **`cors({ origin: true })`**. Restart Node after pull.
4. **Helmet CORP** — `backend/src/config/helmetConfig.js` uses **`crossOriginResourcePolicy: cross-origin`**.
5. **Listen address** — servers default to **`0.0.0.0`** (`LISTEN_HOST`) so Windows/WSL/Docker can reach the port.

Chrome **DevTools → Network** (failed / blocked) and **Console** for CORS / PNA messages.
