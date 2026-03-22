# Flutter app — API base URL & Dio

**Gateway** exposes everything under **`/api/*`**.

Dio **drops** the `/api` segment if request paths start with **`/`** (treated as absolute from host root).  
**Fix (implemented):** `ApiService` uses `dioBaseUrl(...)` (trailing `/`) + `dioRelativePath(...)` (strip leading `/`) so URLs become e.g. `http://host:3000/api/auth/...`.

Share links use `ApiConstants.baseUrl` **without** trailing slash: `.../api/trips/...`.
