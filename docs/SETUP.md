# LuhaRide Development Setup Guide

Complete step-by-step guide to set up the development environment for LuhaRide project.

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

1. **Node.js** (v18 or higher)
   - Download: https://nodejs.org/
   - Verify: `node --version` and `npm --version`

2. **Flutter SDK** (v3.0 or higher)
   - Download: https://docs.flutter.dev/get-started/install
   - Verify: `flutter --version`

3. **PostgreSQL** (v14 or higher)
   - Download: https://www.postgresql.org/download/
   - Verify: `psql --version`

4. **Redis** (v7 or higher)
   - Windows: https://github.com/microsoftarchive/redis/releases
   - Linux: `sudo apt-get install redis-server`
   - macOS: `brew install redis`
   - Verify: `redis-cli --version`

5. **Git**
   - Download: https://git-scm.com/downloads
   - Verify: `git --version`

### Recommended Tools

- **VS Code** with extensions:
  - Flutter
  - Dart
  - ESLint
  - Prettier
  - PostgreSQL

- **Android Studio** (for Android development)
- **Xcode** (for iOS development, macOS only)
- **Postman** (for API testing)

---

## Backend Setup

### 1. Navigate to Backend Directory

```bash
cd D:\cur\luharide\backend
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Configure Environment Variables

```bash
# Copy the example environment file
copy .env.example .env

# Edit .env file with your configuration
notepad .env
```

Update the following variables in `.env`:

```env
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=luharide
DB_USER=postgres
DB_PASSWORD=your_postgres_password

# JWT Secret (generate a strong random string)
JWT_SECRET=your_very_secure_random_string_here

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# Other services (can be configured later)
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token
GOOGLE_MAPS_API_KEY=your_google_maps_key
RAZORPAY_KEY_ID=your_razorpay_key
RAZORPAY_KEY_SECRET=your_razorpay_secret
```

### 4. Setup PostgreSQL Database

Open PostgreSQL command line (psql) or pgAdmin:

```sql
-- Create database
CREATE DATABASE luharide;

-- Connect to the database
\c luharide

-- Enable PostGIS extension
CREATE EXTENSION postgis;

-- Verify PostGIS installation
SELECT PostGIS_Version();
```

### 5. Run Database Migrations

```bash
npm run migrate
```

This will create all the necessary tables and indexes.

### 6. (Optional) Seed Sample Data

```bash
npm run seed
```

This adds sample unions, routes, and vehicles for testing.

### 7. Start Redis Server

**Windows:**
```bash
redis-server
```

**Linux/macOS:**
```bash
redis-server
# Or if installed as service:
sudo systemctl start redis
```

### 8. Start Backend Server

```bash
# Development mode (with auto-reload)
npm run dev

# Or production mode
npm start
```

The server should start on `http://localhost:3000`

### 9. Verify Backend is Running

Open browser and visit:
- Health check: http://localhost:3000/health
- API root: http://localhost:3000/api

You should see JSON responses indicating the server is running.

---

## Mobile App Setup

### 1. Navigate to Mobile Directory

```bash
cd D:\cur\luharide\mobile
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. Configure API Endpoints

Edit `lib/core/config/env_config.dart`:

```dart
class EnvConfig {
  // Update these with your local backend URL
  static const String apiBaseUrl = 'http://localhost:3000/api';
  static const String socketUrl = 'http://localhost:3000';
  
  // Add your API keys when available
  static const String googleMapsApiKey = 'YOUR_KEY';
  static const String razorpayKeyId = 'YOUR_KEY';
}
```

**Note for Android Emulator:**
- Use `http://10.0.2.2:3000` instead of `localhost`

**Note for iOS Simulator:**
- `localhost` should work, or use your computer's local IP

### 4. Setup Android (if developing for Android)

```bash
# Check Android setup
flutter doctor

# Accept Android licenses
flutter doctor --android-licenses
```

### 5. Setup iOS (macOS only, if developing for iOS)

```bash
# Install CocoaPods
sudo gem install cocoapods

# Install iOS dependencies
cd ios
pod install
cd ..
```

### 6. Run the App

```bash
# List available devices
flutter devices

# Run on connected device/emulator
flutter run

# Or specify device
flutter run -d android
flutter run -d ios
```

### 7. Hot Reload

When the app is running:
- Press `r` to hot reload
- Press `R` to hot restart
- Press `q` to quit

---

## Verification Checklist

After setup, verify everything is working:

### Backend Verification

- [ ] PostgreSQL is running (`psql -U postgres`)
- [ ] Redis is running (`redis-cli ping` returns `PONG`)
- [ ] Database `luharide` exists
- [ ] PostGIS extension is enabled
- [ ] All tables are created (check with `\dt` in psql)
- [ ] Backend server starts without errors
- [ ] `/health` endpoint returns `{"status": "ok"}`
- [ ] `/api/auth/login` endpoint responds (even with error is fine)

### Mobile App Verification

- [ ] Flutter is properly installed (`flutter doctor` shows no errors)
- [ ] Dependencies are installed (`flutter pub get` succeeds)
- [ ] App builds successfully (`flutter build` works)
- [ ] App runs on emulator/device
- [ ] Welcome screen displays

---

## Common Issues and Solutions

### Issue: PostgreSQL Connection Failed

**Solution:**
1. Check PostgreSQL is running: `pg_ctl status`
2. Verify credentials in `.env`
3. Check `pg_hba.conf` allows local connections
4. Restart PostgreSQL service

### Issue: Redis Connection Error

**Solution:**
1. Check Redis is running: `redis-cli ping`
2. Verify port 6379 is not blocked
3. Check `.env` has correct Redis configuration

### Issue: Flutter Doctor Shows Errors

**Solution:**
1. Run `flutter doctor` to see specific issues
2. For Android: Install Android Studio and SDK
3. For iOS: Install Xcode (macOS only)
4. Accept licenses: `flutter doctor --android-licenses`

### Issue: Backend Port Already in Use

**Solution:**
1. Change port in `.env`: `PORT=3001`
2. Or kill process using port 3000:
   - Windows: `netstat -ano | findstr :3000` then `taskkill /PID <pid> /F`
   - Linux/Mac: `lsof -ti:3000 | xargs kill`

### Issue: Cannot Connect to Backend from Mobile App

**Solution:**
1. **Android Emulator**: Use `http://10.0.2.2:3000`
2. **iOS Simulator**: Use `http://localhost:3000`
3. **Physical Device**: Use your computer's local IP (e.g., `http://192.168.1.5:3000`)
4. Ensure firewall allows connections on port 3000

---

## Next Steps

After successful setup:

1. **Explore the Code Structure**
   - Review `backend/src/routes/` for API endpoints
   - Check `mobile/lib/presentation/screens/` for UI screens

2. **Test the Health Check**
   ```bash
   curl http://localhost:3000/health
   ```

3. **Run Database Queries**
   ```sql
   -- Connect to database
   psql -U postgres -d luharide
   
   -- Check tables
   \dt
   
   -- Check sample data
   SELECT * FROM unions;
   SELECT * FROM routes;
   ```

4. **Start Development**
   - Begin with authentication module
   - Refer to the main project plan
   - Use TODO items to track progress

---

## Development Workflow

### Backend Development

```bash
cd backend

# Start development server (auto-reloads on changes)
npm run dev

# Run tests
npm test

# Check for linting errors
npm run lint
```

### Mobile Development

```bash
cd mobile

# Run in debug mode
flutter run

# Build for release
flutter build apk  # Android
flutter build ios  # iOS

# Run tests
flutter test

# Analyze code
flutter analyze
```

---

## External Services Setup (To Be Done Later)

These can be configured when implementing specific features:

1. **Google Maps API**
   - Create project in Google Cloud Console
   - Enable Maps SDK for Android/iOS
   - Enable Directions API, Geocoding API
   - Add API key to environment files

2. **Razorpay**
   - Sign up at https://razorpay.com
   - Get API keys from dashboard
   - Add to environment files

3. **Twilio (SMS)**
   - Sign up at https://www.twilio.com
   - Get Account SID and Auth Token
   - Add to environment files

4. **Firebase (Push Notifications)**
   - Create project in Firebase Console
   - Download configuration files
   - Add to mobile app

5. **AWS S3 (File Storage)**
   - Create S3 bucket
   - Set up IAM user with access
   - Add credentials to environment files

---

## Support

If you encounter any issues:

1. Check this documentation first
2. Review error messages carefully
3. Search for similar issues online
4. Check project README.md
5. Contact development team

---

**Setup completed successfully? Start building! 🚀**
