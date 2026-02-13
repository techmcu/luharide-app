# 🔐 PostgreSQL Password Reset Guide

Your PostgreSQL password is NOT `rahul2255`. It's likely still `R@#ul2255` or the original password you set during installation.

## 🎯 Quick Fix (Choose Method A or B)

---

## Method A: Using pgAdmin (Easiest - GUI)

### Step 1: Open pgAdmin
- Search for **"pgAdmin"** in Windows Start Menu
- Open it

### Step 2: Connect to PostgreSQL
- Click on "Servers" → "PostgreSQL [version]"
- It will ask for password
- **Try these passwords one by one:**
  1. `R@#ul2255` (your original password)
  2. `rahul2255` (without special chars)
  3. `postgres` (default)
  4. Leave blank and press Enter
  5. Any other password you might have set

### Step 3: Reset Password
Once connected:
1. Click **Tools** → **Query Tool** (or press F4)
2. Copy and paste this:
   ```sql
   ALTER USER postgres WITH PASSWORD 'postgres123';
   ```
3. Press **F5** or click **Execute** ▶️
4. You should see: "Query returned successfully"

### Step 4: Update .env
Open new terminal:
```powershell
cd D:\cur\luharide\backend
node update-password.js
```
When prompted, enter: `postgres123`

### Step 5: Test
```powershell
npm run test-db
```
Should show: ✅ Connection successful!

---

## Method B: Using SQL Shell (psql)

### Step 1: Open SQL Shell
- Search for **"SQL Shell (psql)"** in Windows Start Menu
- Open it

### Step 2: Connect
Press **Enter** 4 times to accept defaults:
- Server: [localhost] → Press Enter
- Database: [postgres] → Press Enter
- Port: [5432] → Press Enter
- Username: [postgres] → Press Enter
- Password: **Now try these:**
  1. `R@#ul2255`
  2. `rahul2255`
  3. `postgres`
  4. Your Windows password
  5. Leave blank and press Enter

### Step 3: Reset Password
Once connected (you'll see `postgres=#`), run:
```sql
ALTER USER postgres WITH PASSWORD 'postgres123';
```
Press Enter. Should show: `ALTER ROLE`

Type `\q` and press Enter to quit.

### Step 4: Update .env
```powershell
cd D:\cur\luharide\backend
node update-password.js
```
Enter: `postgres123`

### Step 5: Test
```powershell
npm run test-db
```
Should show: ✅ Connection successful!

---

## Method C: Reset Without Knowing Current Password

If you **completely forgot** your password:

### Step 1: Find PostgreSQL Data Directory
Usually: `C:\Program Files\PostgreSQL\[version]\data\`

### Step 2: Edit pg_hba.conf
1. **Right-click** `pg_hba.conf` → **Open with** → **Notepad** (as Administrator)
2. Find this line (near the bottom):
   ```
   host    all             all             127.0.0.1/32            scram-sha-256
   ```
   OR:
   ```
   host    all             all             127.0.0.1/32            md5
   ```

3. **Change `scram-sha-256` or `md5` to `trust`**:
   ```
   host    all             all             127.0.0.1/32            trust
   ```

4. **Save** the file

### Step 3: Restart PostgreSQL Service
1. Open **Services** (search in Start Menu)
2. Find **"postgresql-x64-[version]"**
3. Right-click → **Restart**

### Step 4: Connect Without Password
Open SQL Shell (psql) and press Enter 5 times (including password - just press Enter)

### Step 5: Reset Password
```sql
ALTER USER postgres WITH PASSWORD 'postgres123';
```

### Step 6: Revert pg_hba.conf
1. Open `pg_hba.conf` again
2. Change `trust` back to `scram-sha-256` or `md5`
3. Save

### Step 7: Restart PostgreSQL Again
In Services, restart PostgreSQL service

### Step 8: Update .env and Test
```powershell
cd D:\cur\luharide\backend
node update-password.js
# Enter: postgres123

npm run test-db
# Should work now!
```

---

## ✅ After Password Reset Works

Once `npm run test-db` shows success:

```powershell
# Create database and enable PostGIS
npm run setup-db

# Create all tables
npm run migrate

# (Optional) Add sample data
npm run seed

# Start server
npm run dev
```

Then visit: http://localhost:3000/health

Should return:
```json
{
  "status": "ok",
  "database": "connected",
  "redis": "not available"
}
```

---

## 🆘 Still Not Working?

### Check PostgreSQL is Running
1. Open **Services**
2. Find **"postgresql-x64-[version]"**
3. Status should be **"Running"**
4. If not, right-click → **Start**

### Check Port
In pgAdmin or psql, run:
```sql
SHOW port;
```
Should be `5432`. If different, update `DB_PORT` in `.env`

### Check Installation
Open Command Prompt:
```cmd
psql --version
```
Should show PostgreSQL version. If not found, reinstall PostgreSQL.

---

## 📞 Summary

**The issue:** Your PostgreSQL password ≠ password in `.env`

**The fix:** 
1. Connect to PostgreSQL with CURRENT password
2. Reset to simple password: `postgres123`
3. Update `.env` with new password
4. Test connection: `npm run test-db`
5. Setup database: `npm run setup-db`
6. Done! 🎉

---

**Most people succeed with Method A (pgAdmin) using their original password `R@#ul2255`** ✨
