# Fix PostgreSQL Password

## Step 1: Open pgAdmin

1. Open **pgAdmin** (search in Windows Start Menu)
2. Connect to your PostgreSQL server
3. Enter your **current password** (try both: `R@#ul2255` or `rahul2255`)

## Step 2: Reset Password to Simple One

In pgAdmin Query Tool, run this:

```sql
ALTER USER postgres WITH PASSWORD 'postgres123';
```

Press **F5** or click **Execute**.

## Step 3: Update .env File

Back in your terminal:

```powershell
cd D:\cur\luharide\backend
node update-password.js
```

When prompted, enter: `postgres123`

## Step 4: Test Connection

```powershell
npm run test-db
```

Should show: ✅ Connection successful!

## Step 5: Setup Database

```powershell
npm run setup-db
```

This creates the database and enables PostGIS.

## Step 6: Run Migrations

```powershell
npm run migrate
```

Creates all tables.

## Step 7: Start Server

```powershell
npm run dev
```

## Step 8: Test

Open browser: http://localhost:3000/health

Should return:
```json
{
  "status": "ok",
  "database": "connected"
}
```

---

## Alternative: If pgAdmin Doesn't Open

Use **SQL Shell (psql)**:

1. Search for "SQL Shell (psql)" in Windows Start Menu
2. Press Enter to accept defaults (localhost, postgres, etc.)
3. Enter your current password when prompted
4. Run: `ALTER USER postgres WITH PASSWORD 'postgres123';`
5. Type: `\q` to quit
6. Continue with Step 3 above

---

## If You Forgot Your Password

1. Find `pg_hba.conf` file (usually in `C:\Program Files\PostgreSQL\[version]\data\`)
2. Open as Administrator
3. Find line: `host all all 127.0.0.1/32 md5`
4. Change `md5` to `trust`
5. Save and restart PostgreSQL service
6. Connect without password
7. Reset password: `ALTER USER postgres WITH PASSWORD 'postgres123';`
8. Change `trust` back to `md5` in pg_hba.conf
9. Restart PostgreSQL service again
