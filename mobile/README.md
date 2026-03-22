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

See also: `../docs/MICROSERVICES_RUN.md`, `../docs/MOBILE_DIO_API_BASE.md`.

---

## Getting Started

This project is a starting point for a Flutter application.

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/).
