# ⚡ LuhaRide - Quick Start Guide

**For Developers joining the project**

---

## 🎯 What is LuhaRide?

Legal taxi aggregator platform for Uttarakhand with **seat-wise booking** to prevent overcrowding. Think Ola/Uber but:
- ✅ Only legal yellow-plate commercial taxis
- ✅ Seat selection like train booking
- ✅ Union-integrated, not ride-sharing
- ✅ Real-time tracking & safety features

**Target Users:** Passengers, Drivers, Union Admins (single app, 3 dashboards)

---

## 📁 Project Structure

```
luharide/
├── backend/              # Node.js + Express API
│   ├── src/
│   │   ├── controllers/  # Request handlers
│   │   ├── services/     # Business logic
│   │   ├── models/       # (Future: if using ORM)
│   │   ├── routes/       # API endpoints
│   │   ├── middleware/   # Auth, validation, error handling
│   │   ├── config/       # Database, Redis, environment
│   │   ├── utils/        # Helpers
│   │   └── socket/       # WebSocket handlers
│   ├── migrations/       # Database schema changes
│   ├── seeders/          # Sample data
│   ├── tests/            # Unit & integration tests
│   └── server.js         # Entry point
│
├── mobile/               # Flutter mobile app
│   └── lib/
│       ├── main.dart     # App entry
│       ├── core/         # Config, theme, constants
│       ├── data/         # Models, repositories, services
│       ├── presentation/ # Screens, widgets
│       └── providers/    # State management
│
└── docs/                 # Documentation
    ├── DEVELOPMENT_ROADMAP.md     # 16-week plan
    ├── TECHNICAL_SPEC.md          # Complete tech spec
    ├── PROJECT_STATUS.md          # Current progress
    └── this file
```

---

## 🚀 Setup (First Time)

### Prerequisites

**Install these first:**
```bash
# Node.js 18+ and npm
node --version  # Should show v18.x or higher
npm --version

# PostgreSQL 14+
psql --version  # Should show 14.x or higher

# Flutter 3.x
flutter --version  # Should show 3.x

# Git
git --version
```

### Backend Setup

```bash
# 1. Navigate to backend
cd D:\cur\luharide\backend

# 2. Install dependencies
npm install

# 3. Setup environment variables
# Edit .env file with your values:
# - DB_PASSWORD (your PostgreSQL password)
# - JWT_SECRET (generate random string)
# - RAZORPAY_KEY, TWILIO_AUTH, etc.

# 4. Test database connection
npm run test-db

# 5. Run migrations (create tables)
npm run migrate

# 6. Seed sample data (optional)
npm run seed

# 7. Start development server
npm run dev
```

**Server should start at:** `http://localhost:3000`

**Test health endpoint:**
```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2026-02-11T...",
  "database": "connected",
  "redis": "not available"
}
```

### Mobile App Setup

```bash
# 1. Navigate to mobile
cd D:\cur\luharide\mobile

# 2. Get Flutter dependencies
flutter pub get

# 3. Check for issues
flutter doctor

# 4. Run on emulator/device
flutter run

# OR for specific device
flutter run -d <device-id>
```

**First launch will show:** Welcome Screen (placeholder)

---

## 🛠️ Daily Development

### Starting Work

```bash
# Terminal 1: Backend server
cd D:\cur\luharide\backend
npm run dev         # Nodemon (auto-restart on changes)

# Terminal 2: Flutter app
cd D:\cur\luharide\mobile
flutter run

# Terminal 3: PostgreSQL (if needed)
psql -U postgres -d luharide
```

### Common Commands

**Backend:**
```bash
npm run dev          # Start with auto-reload
npm test             # Run tests
npm run migrate      # Run new migrations
npm run seed         # Seed database
npm run test-db      # Test DB connection
```

**Mobile:**
```bash
flutter run                    # Run app
flutter run -d chrome         # Run on web
flutter pub get               # Install dependencies
flutter clean                 # Clean build
flutter test                  # Run tests
flutter build apk             # Build Android APK
```

**Database:**
```bash
# Connect to database
psql -U postgres -d luharide

# Useful queries
\dt                          # List tables
\d table_name                # Describe table
SELECT * FROM users LIMIT 5; # View users
```

---

## 📂 Key Files to Know

### Backend

**`server.js`** - Main entry, Express setup
```javascript
// Key sections:
- Middleware configuration
- Route mounting
- Socket.io setup
- Error handling
- Server startup
```

**`.env`** - Environment variables (NEVER COMMIT!)
```bash
# Must configure:
DB_PASSWORD=your_postgres_password
JWT_SECRET=random_long_string
PORT=3000
```

**`src/routes/*.js`** - API endpoints
```javascript
// Example: src/routes/auth.js
router.post('/auth/login', authController.login);
```

**`src/middleware/errorHandler.js`** - Error handling
```javascript
// Catches all errors, sends standardized response
```

**`migrations/*.sql`** - Database schema
```sql
-- All table definitions
-- Run with: npm run migrate
```

### Mobile

**`lib/main.dart`** - App entry
```dart
void main() {
  runApp(const LuhaRideApp());
}
```

**`lib/core/config/env_config.dart`** - Environment config
```dart
static const String apiBaseUrl = 'http://localhost:3000/api/v1';
```

**`pubspec.yaml`** - Dependencies
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1  # State management
  dio: ^5.4.0       # HTTP client
  # ... 20+ more packages
```

**`lib/providers/*.dart`** - State management
```dart
// Example: AuthProvider
// Manages user authentication state
```

---

## 🎯 Feature Development Flow

### Adding a New Feature

**Example: Implement "Send OTP" endpoint**

#### Step 1: Backend API

**1. Create service** (`src/services/otpService.js`):
```javascript
class OTPService {
  generateOTP() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }
  
  async saveOTP(phone, otp) {
    // Save to database
  }
  
  async verifyOTP(phone, otp) {
    // Verify from database
  }
}

module.exports = new OTPService();
```

**2. Create controller** (`src/controllers/authController.js`):
```javascript
const otpService = require('../services/otpService');

exports.sendOTP = async (req, res, next) => {
  try {
    const { phone } = req.body;
    
    // Generate OTP
    const otp = otpService.generateOTP();
    
    // Save to database
    await otpService.saveOTP(phone, otp);
    
    // Send SMS (TODO: Twilio integration)
    console.log(`OTP for ${phone}: ${otp}`);
    
    res.json({
      success: true,
      message: 'OTP sent successfully',
      expiresIn: 300 // 5 minutes
    });
  } catch (error) {
    next(error);
  }
};
```

**3. Add route** (`src/routes/auth.js`):
```javascript
const router = require('express').Router();
const authController = require('../controllers/authController');

router.post('/send-otp', authController.sendOTP);

module.exports = router;
```

**4. Test**:
```bash
# Using curl
curl -X POST http://localhost:3000/api/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "+919876543210"}'

# Expected response
{
  "success": true,
  "message": "OTP sent successfully",
  "expiresIn": 300
}
```

#### Step 2: Mobile UI

**1. Create API service** (`lib/data/services/auth_service.dart`):
```dart
class AuthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: EnvConfig.apiBaseUrl,
  ));
  
  Future<void> sendOTP(String phone) async {
    try {
      final response = await _dio.post('/auth/send-otp', data: {
        'phone': phone,
      });
      
      if (response.data['success']) {
        return;
      } else {
        throw Exception(response.data['message']);
      }
    } catch (e) {
      throw Exception('Failed to send OTP: $e');
    }
  }
}
```

**2. Create provider** (`lib/providers/auth_provider.dart`):
```dart
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  bool _isLoading = false;
  String? _error;
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  Future<void> sendOTP(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _authService.sendOTP(phone);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
```

**3. Create screen** (`lib/presentation/screens/auth/phone_input_screen.dart`):
```dart
class PhoneInputScreen extends StatefulWidget {
  @override
  _PhoneInputScreenState createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  
  Future<void> _sendOTP() async {
    final phone = _phoneController.text;
    final authProvider = context.read<AuthProvider>();
    
    try {
      await authProvider.sendOTP(phone);
      // Navigate to OTP screen
      Navigator.pushNamed(context, '/otp-verification');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Enter Phone Number')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixText: '+91 ',
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sendOTP,
              child: Text('Send OTP'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**4. Test on device:**
```bash
flutter run
# Navigate to phone input screen
# Enter phone number
# Tap "Send OTP"
# Check terminal for OTP (until SMS integrated)
```

---

## 🧪 Testing

### Backend Testing

**Unit Test Example** (`tests/unit/otpService.test.js`):
```javascript
const otpService = require('../../src/services/otpService');

describe('OTPService', () => {
  test('generateOTP should return 6-digit number', () => {
    const otp = otpService.generateOTP();
    expect(otp).toHaveLength(6);
    expect(Number(otp)).toBeGreaterThanOrEqual(100000);
    expect(Number(otp)).toBeLessThanOrEqual(999999);
  });
  
  test('saveOTP should store OTP in database', async () => {
    const phone = '+919999999999';
    const otp = '123456';
    
    await otpService.saveOTP(phone, otp);
    
    const saved = await otpService.verifyOTP(phone, otp);
    expect(saved).toBe(true);
  });
});
```

**Run tests:**
```bash
npm test                    # All tests
npm test -- otpService      # Specific test
npm test -- --coverage      # With coverage
```

### Mobile Testing

**Widget Test Example** (`test/phone_input_test.dart`):
```dart
void main() {
  testWidgets('Phone input screen shows text field', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PhoneInputScreen(),
      ),
    );
    
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });
}
```

**Run tests:**
```bash
flutter test                           # All tests
flutter test test/phone_input_test.dart  # Specific test
flutter test --coverage                # With coverage
```

---

## 🐛 Debugging

### Backend Debugging

**Console Logs:**
```javascript
console.log('Debug:', variable);  // Basic
console.error('Error:', error);   // Errors
console.table(data);               // Tables
```

**VS Code Debugger:**
```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Debug Backend",
      "skipFiles": ["<node_internals>/**"],
      "program": "${workspaceFolder}/backend/server.js"
    }
  ]
}
```

### Mobile Debugging

**Print Statements:**
```dart
print('Debug: $variable');
debugPrint('This is a debug message');
```

**Flutter DevTools:**
```bash
flutter run
# Then press 'v' in terminal to open DevTools
```

**VS Code Debugger:**
```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter",
      "request": "launch",
      "type": "dart"
    }
  ]
}
```

---

## 📚 Documentation

### API Documentation

**After implementing endpoint, document it:**

```yaml
# backend/src/docs/swagger.yaml
/auth/send-otp:
  post:
    summary: Send OTP to phone number
    requestBody:
      required: true
      content:
        application/json:
          schema:
            type: object
            properties:
              phone:
                type: string
                example: "+919876543210"
    responses:
      200:
        description: OTP sent successfully
```

### Code Comments

**Good comments explain WHY, not WHAT:**

```javascript
// ❌ Bad: Obvious
// Loop through users
for (const user of users) { ... }

// ✅ Good: Explains reasoning
// We check for expired accounts here instead of a cron job
// to ensure real-time accuracy for security-critical operations
if (user.accountExpired()) { ... }
```

---

## 🔧 Common Issues & Fixes

### Issue 1: "Cannot connect to database"
```bash
# Check if PostgreSQL is running
pg_isready -U postgres

# If not, start it (Windows)
# Open Services → PostgreSQL → Start

# Test connection
npm run test-db
```

### Issue 2: "Port 3000 already in use"
```bash
# Find process using port 3000
netstat -ano | findstr :3000

# Kill process (replace PID)
taskkill /PID <PID> /F

# OR change port in .env
PORT=3001
```

### Issue 3: "Flutter pub get failed"
```bash
# Clean Flutter
flutter clean

# Delete pubspec.lock
del pubspec.lock

# Get packages again
flutter pub get
```

### Issue 4: "Migration failed"
```bash
# Check database exists
psql -U postgres -l

# If not, create it
npm run setup-db

# Then run migration
npm run migrate
```

---

## 🎨 Code Style

### Backend (JavaScript)

```javascript
// Use const/let, not var
const apiUrl = 'http://...';
let counter = 0;

// Arrow functions for short functions
const double = (n) => n * 2;

// async/await over promises
async function fetchData() {
  const data = await api.get('/data');
  return data;
}

// Descriptive variable names
const userBookings = await Booking.findAll({ userId });  // ✅
const x = await Booking.findAll({ userId });            // ❌

// Early returns
if (!user) return res.status(404).json({ error: 'Not found' });
// ... rest of logic
```

### Mobile (Dart)

```dart
// Use const for immutable widgets
const Text('Hello');

// Prefer final over var
final userName = 'John';

// Null safety
String? optionalString;  // Can be null
String requiredString;   // Cannot be null

// Descriptive names
final userBookings = await bookingRepository.getUserBookings(userId);  // ✅
final x = await bookingRepository.getUserBookings(userId);             // ❌

// Early returns
if (user == null) return;
// ... rest of logic
```

---

## 🚢 Deployment Checklist

**Before deploying to production:**

- [ ] All tests passing
- [ ] No console.log/print statements in production code
- [ ] Environment variables configured
- [ ] Database migrations run
- [ ] SSL certificate installed
- [ ] API keys secured (not in code)
- [ ] Error logging setup (Sentry)
- [ ] Monitoring setup (New Relic)
- [ ] Backup strategy in place
- [ ] Load testing completed
- [ ] Security audit done

---

## 📞 Getting Help

### Resources

**Documentation:**
- `DEVELOPMENT_ROADMAP.md` - Full 16-week plan
- `TECHNICAL_SPEC.md` - Complete technical details
- `PROJECT_STATUS.md` - Current progress
- `docs/SETUP.md` - Detailed setup guide

**Online:**
- Node.js docs: https://nodejs.org/docs
- Flutter docs: https://flutter.dev/docs
- PostgreSQL docs: https://www.postgresql.org/docs
- Express docs: https://expressjs.com
- Socket.io docs: https://socket.io/docs

**Community:**
- Stack Overflow (tag questions appropriately)
- Flutter Discord
- Node.js Discord

---

## ✅ Daily Checklist

**Every day before starting:**
- [ ] Pull latest code: `git pull`
- [ ] Check for dependency updates
- [ ] Review PROJECT_STATUS.md for current sprint
- [ ] Start backend server
- [ ] Start mobile app
- [ ] Check health endpoint

**Every day before ending:**
- [ ] Commit your changes with clear message
- [ ] Push to remote branch
- [ ] Update PROJECT_STATUS.md if milestone reached
- [ ] Document any issues/blockers

---

## 🎯 Quick Commands Reference

```bash
# Backend
cd D:\cur\luharide\backend
npm run dev                  # Start server
npm test                     # Run tests
npm run migrate              # Run migrations
npm run test-db              # Test database

# Mobile
cd D:\cur\luharide\mobile
flutter run                  # Run app
flutter test                 # Run tests
flutter pub get              # Get dependencies
flutter clean                # Clean build

# Database
psql -U postgres -d luharide    # Connect to DB
\dt                             # List tables
\d users                        # Describe users table
SELECT * FROM users LIMIT 5;   # Query users

# Git
git status                   # Check status
git add .                    # Stage changes
git commit -m "message"      # Commit
git push                     # Push to remote
git pull                     # Pull from remote
```

---

**🎉 You're ready to start developing! Begin with Phase 1, Week 1.**

**First task:** Implement authentication system (OTP + JWT)

**Questions?** Check `DEVELOPMENT_ROADMAP.md` for detailed step-by-step guide.
