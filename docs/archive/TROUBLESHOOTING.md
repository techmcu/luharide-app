# 🔧 Troubleshooting Guide - LuhaRide

## Current Issue: Password Authentication Failed

Your password contains special characters (`@` and `#`) which can cause issues with PostgreSQL connections.

---

## 🚀 Quick Fix (Choose One)

### Option 1: Test Database Connection First

Run this to see detailed error information:

```powershell
cd D:\cur\luharide\backend
npm run test-db
```

This will show exactly what's wrong with the connection.

### Option 2: Setup Database Automatically

This creates the database and enables PostGIS:

```powershell
npm run setup-db
```

If it fails with password error, try Option 3.

### Option 3: Reset PostgreSQL Password (Recommended)

Your current password `R@#ul2255` has special characters that may cause issues.

**Steps:**

1. Open **pgAdmin** or **SQL Shell (psql)**

2. Connect to PostgreSQL (use your current password when prompted)

3. Run this command:
   ```sql
   ALTER USER postgres WITH PASSWORD 'newSimplePass123';
   ```

4. Update the password in `.env` file:
   ```powershell
   node update-password.js
   ```
   Enter: `newSimplePass123`

5. Restart server:
   ```powershell
   npm run dev
   ```

---

## 📋 Step-by-Step Database Setup

### Step 1: Verify PostgreSQL is Running

**Check if PostgreSQL service is running:**
- Windows: Open Services → Find "PostgreSQL" → Should be "Running"
- Or run: `pg_isready` in terminal

### Step 2: Connect to PostgreSQL

Open **pgAdmin** or **psql** and connect with your password.

### Step 3: Create Database

In pgAdmin or psql, run:

```sql
-- Create database
CREATE DATABASE luharide;

-- Connect to it
\c luharide

-- Enable PostGIS
CREATE EXTENSION postgis;

-- Verify
SELECT PostGIS_Version();
```

### Step 4: Update .env Password

If needed, update the password:

```powershell
node update-password.js
```

### Step 5: Test Connection

```powershell
npm run test-db
```

Should show: `✅ Connection successful!`

### Step 6: Run Migrations

```powershell
npm run migrate
```

This creates all tables (users, vehicles, bookings, etc.)

### Step 7: Start Server

```powershell
npm run dev
```

### Step 8: Test Health

Open browser: http://localhost:3000/health

Should return:
```json
{
  "status": "ok",
  "database": "connected",
  "redis": "not available"
}
```

---

## 🔍 Common Errors & Solutions

### Error: "password authentication failed"

**Causes:**
- Wrong password in `.env` file
- Special characters in password
- User doesn't exist

**Solutions:**
1. Double-check password in `.env` matches PostgreSQL
2. Try resetting to a simpler password (no special chars)
3. Verify user exists: `\du` in psql

### Error: "database luharide does not exist"

**Solution:**
```sql
CREATE DATABASE luharide;
```

Or run: `npm run setup-db`

### Error: "ECONNREFUSED"

**Causes:**
- PostgreSQL service not running
- Wrong port (should be 5432)

**Solutions:**
1. Start PostgreSQL service
2. Check port: `SHOW port;` in psql
3. Verify `DB_PORT=5432` in `.env`

### Error: "pg module not found"

**Solution:**
```powershell
npm install
```

### Error: "PostGIS extension not available"

**Solution:**
PostGIS might not be installed. Install it:
- Windows: Include "PostGIS" during PostgreSQL installation
- Or download from: https://postgis.net/install/

---

## 🔐 Password Best Practices

### Good Passwords (for development):
- `postgres123`
- `devPassword`
- `local_dev_pass`

### Avoid (causes issues):
- `R@#ul2255` (special characters)
- `pass word` (spaces)
- `"password"` (quotes)

### For Production:
- Use environment variables
- Use strong passwords with proper escaping
- Use connection strings instead
- Use SSL/TLS

---

## 📊 Verification Checklist

After setup, verify everything:

- [ ] PostgreSQL service is running
- [ ] Password is correct in `.env`
- [ ] Database "luharide" exists
- [ ] PostGIS extension enabled
- [ ] `npm run test-db` passes
- [ ] `npm run migrate` creates tables
- [ ] `npm run dev` starts server
- [ ] http://localhost:3000/health returns success

---

## 🆘 Still Having Issues?

### Check These Files:

1. **`.env`** - Verify all settings:
   ```env
   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=luharide
   DB_USER=postgres
   DB_PASSWORD=your_actual_password
   ```

2. **PostgreSQL Config** - Check `pg_hba.conf`:
   - Should allow local connections
   - Method should be `md5` or `trust` for localhost

### Get Detailed Logs:

```powershell
# Set debug mode
$env:DEBUG="*"
npm run dev
```

### Test Each Component:

```powershell
# Test database connection
npm run test-db

# Test database setup
npm run setup-db

# Check PostgreSQL version
psql --version

# Check if database exists
psql -U postgres -l
```

---

## 📞 Next Steps After Fixing

Once database connection works:

1. **Run Migrations:**
   ```powershell
   npm run migrate
   ```
   Creates all 15 tables with proper schema

2. **Add Sample Data (Optional):**
   ```powershell
   npm run seed
   ```
   Adds test unions, routes, vehicles

3. **Start Development:**
   ```powershell
   npm run dev
   ```
   Server starts on http://localhost:3000

4. **Test APIs:**
   - Health: http://localhost:3000/health
   - Auth: http://localhost:3000/api/auth/login

---

## 🎯 Quick Command Reference

```powershell
# Database
npm run test-db      # Test connection
npm run setup-db     # Create database
npm run migrate      # Create tables
npm run seed         # Add sample data

# Server
npm run dev          # Start development server
npm start            # Start production server

# Utilities
node update-password.js  # Update password in .env
```

---

**Most Common Fix: Just reset your PostgreSQL password to something simple without special characters!** 🔐

Try: `ALTER USER postgres WITH PASSWORD 'postgres123';`
