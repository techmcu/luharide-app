# luharide — Flutter app

## Local API (important)

REST paths are always under **`/api/...`**. The thing that must match your terminal is **host + port**, not the path string.

| Backend you run | Port | Flutter (Chrome / emulator) |
|-----------------|------|-------------------------------|
| Monolith `node server.js` | **3000** | `--dart-define=USE_LOCAL_API=true` |
| Microservices `npm run dev:stack` (gateway) | **3010** | `--dart-define=USE_LOCAL_API=true --dart-define=LOCAL_API_PORT=3010` |

Web local API host is **`127.0.0.1`** (not `localhost`) so Chrome hits IPv4 and matches Node on `0.0.0.0`.

If the port is wrong, the browser shows **`XMLHttpRequest onError`** / **`ERROR[null]`** (nothing listening on that port).

Full URLs are built in `lib/services/api_service.dart` (`buildApiUrl`). Override anything with `--dart-define=API_BASE_URL=...`.

### Production (APK + Flutter Web + `luharide.cloud`)

- **Default API** (no dart-defines): `https://api.luharide.cloud` — REST base `.../api`, Socket same host. Override with `--dart-define=API_BASE_URL=...` and `SOCKET_URL=...` if your gateway URL differs.
- **Web build:** `scripts/build_web_production.ps1` (Windows) or `scripts/build_web_production.sh` (Linux/macOS) → upload `build/web/*` to VPS `/var/www/luharide-web/` → run `infra/scripts/setup-root-website-nginx.sh` so the **same Flutter UI** is served on the main domain.
- **Backend:** set `CORS_ALLOWED_ORIGINS` to include `https://luharide.cloud` and `https://www.luharide.cloud` (see `backend/.env.example`). Nginx for `api.*` needs WebSocket **Upgrade** headers — `infra/nginx-reverse-proxy-luharide-api-gateway.example.conf`.

See also: `../docs/MICROSERVICES_RUN.md`, `../docs/MOBILE_DIO_API_BASE.md`.

---

## Getting Started

This project is a starting point for a Flutter application.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/).
