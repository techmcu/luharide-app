# Admin Panel Setup Guide

## Problem: Admin login shows passenger screen

### Fix Steps:

### 1. **Logout First** (IMPORTANT!)
```
App → Profile → Scroll down → Logout button
```
Ya app ko force close karo aur restart karo.

### 2. **Create Demo Accounts**
Login screen par:
1. **"Create Demo Accounts"** button press karo
2. Wait for success message: "Demo accounts created!"

### 3. **Fill Admin Credentials**
1. **"Fill Admin"** button press karo
2. Email aur password automatically fill ho jayenge:
   - Email: `admin@luharide.com`
   - Password: `Admin@123`

### 4. **Login**
1. **"Login"** button press karo
2. Admin panel automatically open hoga

---

## Admin Panel Features

### What you'll see:
- **Purple header** with "Admin Panel"
- **Driver verification requests** (pending requests list)
- **Approve/Reject buttons** for each request
- **NO SEARCH BAR** (that's for passengers)

### What admin can do:
1. View driver verification requests
2. Check driver documents (license, vehicle registration)
3. Approve or reject requests
4. Logout

---

## If still showing passenger screen:

### Debug Check:
Look at Flutter console/logs for:
```
🔍 HomeScreen - User: admin@luharide.com, Role: union_admin
✅ Showing Admin Panel
```

If you see:
```
👤 Showing Passenger/Driver Screen
```
Then the role is NOT union_admin. Check:

### 1. **Backend must be running**
```bash
cd backend
node server.js
```

### 2. **Create demo accounts in backend manually**
```bash
cd backend
node -e "const { pool } = require('./src/config/database'); const bcrypt = require('bcryptjs'); (async () => { const hash = await bcrypt.hash('Admin@123', 10); await pool.query('DELETE FROM users WHERE email = $1', ['admin@luharide.com']); await pool.query('INSERT INTO users (name, email, password_hash, role, is_verified, is_active, phone) VALUES ($1, $2, $3, $4, TRUE, TRUE, $5)', ['LuhaRide Admin', 'admin@luharide.com', hash, 'union_admin', 'admin@luharide.com']); console.log('✅ Admin created'); process.exit(0); })().catch(e => { console.error(e); process.exit(1); });"
```

### 3. **Check database**
```sql
SELECT email, role FROM users WHERE email = 'admin@luharide.com';
```
Role should be: `union_admin`

### 4. **Clear app cache**
In app:
1. Logout
2. Force close app
3. Restart app
4. Login again

---

## Common Issues:

### Issue 1: "Invalid credentials"
**Fix**: Press "Create Demo Accounts" first

### Issue 2: Still showing passenger screen after login
**Fix**: 
1. Check Flutter console logs (see debug check above)
2. Logout and login again
3. Make sure role is 'union_admin' in database

### Issue 3: Backend not responding
**Fix**: 
```bash
cd backend
# Check if .env has correct DB credentials
node server.js
```

---

## Backend Requirements:

### Environment variables (.env):
```
DB_HOST=localhost
DB_PORT=5432
DB_NAME=luharide
DB_USER=postgres
DB_PASSWORD=your_password
```

### Database must be running:
```bash
# Check PostgreSQL is running
psql -U postgres -d luharide -c "SELECT 1;"
```

---

## Flow Chart:

```
Landing Screen
    ↓
Login (same for all users)
    ↓
[Backend checks email + password]
    ↓
Returns user with role
    ↓
[HomeScreen checks role]
    ↓
If role = 'union_admin' or 'admin'
    → UnionAdminHomeScreen (Admin Panel)
    
Otherwise
    → PassengerHomeScreen (Search rides)
```

---

## Need Help?

Check Flutter console logs first:
- Look for: `🔍 HomeScreen - User: ..., Role: ...`
- Role should be `union_admin` for admin panel
- If role is different, create demo accounts again or check database
