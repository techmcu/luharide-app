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

The request URL is correct (e.g. `http://127.0.0.1:3000/api/...`) but the browser shows a **network layer** error and **no HTTP status**.

1. **Backend not running** — start from `backend`: `node server.js` (or your gateway stack). Confirm `http://127.0.0.1:3000/health` in the browser.
2. **Helmet CORP** — older defaults sent `Cross-Origin-Resource-Policy: same-origin`, which blocks Flutter Web (different origin = different port) from reading the response. The repo sets **`crossOriginResourcePolicy: cross-origin`** in `backend/src/config/helmetConfig.js`. **Restart the Node server** after pulling.
3. Chrome **DevTools → Network**: see if the request is **(failed)** or **blocked**; **Console** may show CORS/CORP messages.
