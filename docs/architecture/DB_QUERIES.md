# LuhaRide Database Quick Queries (PostgreSQL)

DB config (backend `.env`):

- `DB_NAME=luharide`
- `DB_USER=luharide_user`
- `DB_PASSWORD=rahul@123`

---

## 1. PSQL login

SSH ke baad server par:

```bash
cd /var/www/luharide-backend
PGPASSWORD='rahul@123' psql -U luharide_user -d luharide -h localhost
```

PSQL se bahar:

```sql
\q
```

---

## 2. Users (accounts)

Sab users dekhna:

```sql
SELECT id, email, created_at
FROM users
ORDER BY created_at DESC
LIMIT 20;
```

Total users count:

```sql
SELECT COUNT(*) AS total_users
FROM users;
```

Sirf admin confirm:

```sql
SELECT id, email
FROM users
WHERE LOWER(email) = 'orahulpanwar@gmail.com';
```

---

## 3. Driver rides (`trips`)

Latest 10 trips:

```sql
SELECT id, from_location, to_location, departure_time, status
FROM trips
ORDER BY created_at DESC
LIMIT 10;
```

Specific route (example: Purola → Dehradun):

```sql
SELECT id, from_location, to_location, departure_time, status
FROM trips
WHERE LOWER(from_location) LIKE '%purola%'
  AND LOWER(to_location) LIKE '%dehradun%'
ORDER BY departure_time DESC
LIMIT 10;
```

---

## 4. Union rides (`union_schedules`)

Latest 10 union rides:

```sql
SELECT id, from_location, to_location, departure_time, status
FROM union_schedules
ORDER BY created_at DESC
LIMIT 10;
```

Specific route (example: Dehradun → Purola):

```sql
SELECT id, from_location, to_location, departure_time, status
FROM union_schedules
WHERE LOWER(from_location) LIKE '%dehradun%'
  AND LOWER(to_location) LIKE '%purola%'
ORDER BY departure_time DESC
LIMIT 10;
```

---

## 5. Unions list (`unions`)

Saare unions with status:

```sql
SELECT id, name, address, status, created_at
FROM unions
ORDER BY created_at DESC
LIMIT 20;
```

Sirf pending unions:

```sql
SELECT id, name, address, status, created_at
FROM unions
WHERE status = 'pending'
ORDER BY created_at DESC;
```

Sirf approved unions:

```sql
SELECT id, name, address, status, created_at
FROM unions
WHERE status = 'approved'
ORDER BY created_at DESC;
```

---

## 6. Test data reset (careful)

**NOTE:** Ye commands PSQL ke andar chalani hain, aur ye sirf test data hataate hain (tables/schema safe).  
Sirf tab use karo jab tum fresh testing environment chaho.

### 6.1 Rides, bookings, unions ka data saaf karna

```sql
DELETE FROM bookings;
DELETE FROM trips;
DELETE FROM union_schedules;
DELETE FROM union_drivers;
DELETE FROM union_routes;
DELETE FROM recent_routes;
DELETE FROM union_admins;
DELETE FROM notifications;
```

### 6.2 Sirf admin user bachana

```sql
DELETE FROM users
WHERE email IS NULL
   OR LOWER(email) <> 'orahulpanwar@gmail.com';
```

Admin confirm:

```sql
SELECT id, email
FROM users;
```

---

## 7. Generic pattern

Kisi bhi table ka latest data dekhna:

```sql
SELECT *
FROM <table_name>
ORDER BY created_at DESC
LIMIT 10;
```

