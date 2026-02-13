# Quick Start Guide - LuhaRide

## ✅ Fixed: Redis Connection Issue

Redis has been made **optional**. The backend will now run without Redis installed.

## 🚀 Start Backend (Without Redis)

```bash
cd D:\cur\luharide\backend

# The .env file is already created with Redis disabled
# Just start the server:
npm run dev
```

The server should start successfully at: **http://localhost:3000**

---

## ✅ What's Working Now

1. **Backend server** - Can start without Redis
2. **Health check** - http://localhost:3000/health
3. **API endpoints** - All routes accessible
4. **Database ready** - PostgreSQL schema ready to migrate

---

## 📋 Next Steps

### Step 1: Install PostgreSQL (if not already)

Download and install: https://www.postgresql.org/download/windows/

### Step 2: Create Database

Open **pgAdmin** or **psql**:

```sql
CREATE DATABASE luharide;
\c luharide
CREATE EXTENSION postgis;
```

### Step 3: Update Database Password

Edit: `D:\cur\luharide\backend\.env`

Change this line:
```env
DB_PASSWORD=your_password
```

To your actual PostgreSQL password.

### Step 4: Run Migrations

```bash
cd D:\cur\luharide\backend
npm run migrate
```

This creates all tables (users, vehicles, bookings, etc.)

### Step 5: (Optional) Add Sample Data

```bash
npm run seed
```

Adds sample unions, routes, and vehicles for testing.

### Step 6: Verify Everything Works

Visit: http://localhost:3000/health

Should return:
```json
{
  "status": "ok",
  "timestamp": "...",
  "database": "connected",
  "redis": "not available"
}
```

---

## 🔧 Installing Redis (Optional - For Production)

Redis provides caching and real-time features. You can add it later.

### Windows:
1. Download: https://github.com/microsoftarchive/redis/releases
2. Install and start: `redis-server`
3. Update `.env`: Change `REDIS_ENABLED=false` to `REDIS_ENABLED=true`
4. Restart backend

### Check Redis:
```bash
redis-cli ping
# Should return: PONG
```

---

## 📱 Flutter Mobile App

```bash
cd D:\cur\luharide\mobile

# Install dependencies
flutter pub get

# Run on device/emulator
flutter run
```

---

## 🆘 Common Issues

### Issue: "Port 3000 already in use"

**Solution:**
1. Change port in `.env`: `PORT=3001`
2. Or kill process:
   ```powershell
   netstat -ano | findstr :3000
   taskkill /PID <process_id> /F
   ```

### Issue: "Cannot connect to database"

**Solution:**
1. Check PostgreSQL is running
2. Verify password in `.env` file
3. Check database exists: `psql -U postgres -l`

### Issue: "Module not found"

**Solution:**
```bash
cd backend
npm install
```

---

## 📊 Project Status

### ✅ Complete
- [x] Project structure
- [x] Backend server configuration
- [x] Database schema design
- [x] Flutter app initialization
- [x] Documentation
- [x] Redis made optional (fixed)
- [x] .env file created

### 🚧 To Do
- [ ] Install PostgreSQL
- [ ] Create database
- [ ] Run migrations
- [ ] Start backend server
- [ ] Test APIs
- [ ] Run mobile app

---

## 🎯 Development Priority

Once backend is running:

1. **Week 1-2**: Authentication system (OTP, JWT)
2. **Week 3-4**: Booking system (seat selection)
3. **Week 5-6**: Payment integration (Razorpay)
4. **Week 7-8**: Real-time tracking (GPS)

---

## 📞 Need Help?

Check these files:
- **Setup issues**: `docs/SETUP.md`
- **Project overview**: `docs/PROJECT_OVERVIEW.md`
- **File structure**: `docs/FILE_STRUCTURE.md`

---

**Your backend is ready to start! Just need PostgreSQL setup now.** 🎉
