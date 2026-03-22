# Database ↔ microservices mapping (LuhaRide)

## Reality check

LuhaRide **v1** uses **one PostgreSQL database** and **`public` schema** for all tables. Every Node microservice process uses the **same connection settings** (`DB_*` env vars). That is a valid **“shared database”** microservices pattern for transactional consistency and simpler migrations.

**Strict “database per service”** (separate Postgres instances, no cross-DB FKs) is **not** implemented — it would require event-driven consistency and a large code migration.

## What we added (formal alignment)

Migration **`029_microservice_domain_registry.sql`**:

1. **Empty PostgreSQL schemas** — `ms_auth`, `ms_core`, `ms_union`, `ms_platform`, `ms_shared` — placeholders for future `search_path` / grants / tooling. **Tables are not moved** (moving would break existing `SELECT ... FROM users` without schema prefix).

2. **Registry table** — `public.ms_table_domain` — one row per business table with:
   - **`primary_service`** — owning microservice (`auth` | `core` | `union` | `platform` | `shared`)
   - **`related_services`** — who else reads/writes
   - **`description`**

3. **View** — `public.v_ms_tables_by_service` — easy listing by service.

### Apply migration

```bash
cd backend && npm run migrate
```

Or run `029_microservice_domain_registry.sql` manually on your DB.

### Query ownership

```sql
SELECT * FROM v_ms_tables_by_service;
-- or
SELECT * FROM ms_table_domain WHERE primary_service = 'core';
```

## Table → service (summary)

| Service | Primary tables (examples) |
|---------|---------------------------|
| **shared** | `users` |
| **auth** | `otp_verifications`, `refresh_tokens`, `login_history`, `emergency_contacts` |
| **core** | `routes`, `vehicles`, `trips`, `bookings`, `location_history`, `sos_logs`, `driver_documents`, `driver_verification_requests`, `pending_rate_notifications`, `recent_routes` |
| **union** | `unions`, `union_admins`, `union_drivers`, `union_routes`, `union_schedules` |
| **platform** | `payments`, `reviews`, `ride_ratings`, `notifications`, `settings` |

`users` is **`shared`** because identity is created by **auth** flows but referenced everywhere.

## Operational notes

- **Connection pools:** Each microservice process opens its own pool → watch total connections (see `MICROSERVICES_ARCHITECTURE.md`).
- **Future split:** Use `ms_table_domain` as the checklist when extracting a service to its own database; replicate IDs (UUIDs) and replace FKs with application-level checks or sagas.
