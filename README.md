# LuhaRide - Uttarakhand Taxi Booking Platform

A legal taxi aggregator platform for Uttarakhand that solves passenger wait times and overcrowding issues through digital seat booking, real-time tracking, and union partnerships.

## 🎯 Problem Statement

**Current Issues:**
- Passengers wait 1-2 hours at taxi stands until vehicles are full
- Overcrowding: 10-seat vehicles illegally carry 11-12 passengers
- No advance booking system
- Poor tourist experience
- Driver inefficiency

**Our Solution:**
- Digital seat booking (like train tickets)
- Guaranteed departure times
- Only legal commercial taxis (yellow plates)
- Union partnership model
- Real-time tracking and safety features

## 🏗️ Project Structure

```
luharide/
├── mobile/              # Flutter mobile app (iOS + Android)
│   ├── lib/
│   │   ├── core/       # App configuration, themes, constants
│   │   ├── data/       # Models, repositories, API services
│   │   ├── presentation/  # UI screens and widgets
│   │   └── providers/  # State management
│   └── assets/         # Images, icons, fonts
│
├── backend/            # Node.js + Express API server
│   ├── src/
│   │   ├── config/     # Database, Redis config
│   │   ├── controllers/  # Business logic
│   │   ├── routes/     # API endpoints
│   │   ├── middleware/ # Auth, validation
│   │   ├── models/     # Data models
│   │   ├── services/   # External services
│   │   └── socket/     # WebSocket handlers
│   └── migrations/     # Database migrations
│
└── docs/               # Documentation
```

## 🛠️ Technology Stack

### Frontend (Mobile)
- **Framework:** Flutter 3.x
- **Language:** Dart
- **State Management:** Provider
- **UI:** Material Design 3
- **Maps:** Google Maps Flutter
- **Payments:** Razorpay

### Backend
- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **Database:** PostgreSQL 14+ with PostGIS
- **Cache:** Redis 7+
- **Real-time:** Socket.io
- **Authentication:** JWT

### External Services
- **Maps:** Google Maps API
- **Payments:** Razorpay
- **SMS:** Twilio
- **Push Notifications:** Firebase FCM
- **Storage:** AWS S3

## 🚀 Getting Started

### Prerequisites

- Node.js 18+
- Flutter SDK 3.0+
- PostgreSQL 14+
- Redis 7+

### Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Copy environment file
cp .env.example .env

# Update .env with your configuration

# Run migrations
npm run migrate

# Seed database (optional)
npm run seed

# Start development server
npm run dev
```

The API will be available at `http://localhost:3000`

### Mobile App Setup

```bash
cd mobile

# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# For iOS
flutter run -d ios

# For Android
flutter run -d android
```

### Database Setup

```sql
-- Create database
CREATE DATABASE luharide;

-- Connect to database
\c luharide

-- Enable PostGIS extension
CREATE EXTENSION postgis;

-- Run migrations (automated via npm run migrate)
```

## 📱 Features

### For Passengers
- ✅ Search and book taxi seats online
- ✅ Visual seat selection (like cinema)
- ✅ Guaranteed no overcrowding
- ✅ Real-time taxi tracking
- ✅ QR code based boarding
- ✅ Multiple payment options
- ✅ Trip history and ratings

### For Drivers
- ✅ Digital trip management
- ✅ Pre-confirmed bookings
- ✅ Navigation assistance
- ✅ QR code passenger verification
- ✅ Earnings dashboard
- ✅ Performance analytics

### For Union Admins
- ✅ Fleet management
- ✅ Driver onboarding
- ✅ Revenue analytics
- ✅ Document tracking
- ✅ Compliance monitoring

## 🔒 Security & Compliance

- Only yellow plate commercial vehicles allowed
- Extensive driver verification (DL, police verification)
- Document verification with OCR
- Real-time trip monitoring
- SOS emergency features
- Motor Vehicle Act 1988 compliant

## 📊 API Documentation

API documentation will be available at `/api-docs` once implemented using Swagger/OpenAPI.

### Key Endpoints

```
POST   /api/auth/register       # User registration
POST   /api/auth/login          # User login
GET    /api/trips/available     # Search available trips
POST   /api/bookings            # Create booking
GET    /api/bookings/:id        # Get booking details
POST   /api/trips/:id/start     # Driver: Start trip
```

## 🧪 Testing

```bash
# Backend tests
cd backend
npm test

# Flutter tests
cd mobile
flutter test

# Integration tests
npm run test:integration
```

## 📈 Roadmap

### ✅ Foundation Setup (Week 0) - COMPLETE
- [x] Project structure setup
- [x] Database schema implementation (15 tables)
- [x] Backend server running
- [x] Sample data seeded
- [x] Complete documentation (4 comprehensive guides)

### 🚧 Phase 1: Authentication (Weeks 1-3) - IN PROGRESS
- [ ] OTP generation & verification
- [ ] JWT authentication
- [ ] User management API
- [ ] Mobile auth screens
- [ ] Profile management

### ⏳ Phase 2: Booking System (Weeks 4-7)
- [ ] Route & vehicle management
- [ ] Seat selection with concurrency
- [ ] QR code generation
- [ ] Mobile booking UI
- [ ] Trip management

### ⏳ Phase 3: Payment & Tracking (Weeks 8-10)
- [ ] Razorpay integration
- [ ] Real-time GPS tracking
- [ ] Driver app features
- [ ] Live map updates

### ⏳ Phase 4: Safety & Admin (Weeks 11-14)
- [ ] SOS system
- [ ] Control room dashboard
- [ ] Union admin panel
- [ ] Analytics & reports

### ⏳ Phase 5: Launch (Weeks 15-16)
- [ ] Testing & optimization
- [ ] Production deployment
- [ ] Pilot with partner union
- [ ] Full launch

**📊 Overall Progress:** 15% Complete  
**📅 Estimated MVP Launch:** June 2026 (16 weeks)

**For detailed roadmap, see [docs/architecture/DEVELOPMENT_ROADMAP.md](docs/architecture/DEVELOPMENT_ROADMAP.md)**

**📚 All documentation is organized under [`docs/`](docs/README.md) — see the index for the full map.**

## 🤝 Contributing

This is a private project. For questions or contributions, contact the development team.

## 📄 License

Proprietary - All rights reserved

## 📞 Support

For support and queries, contact:
- Email: support@luharide.com
- Phone: +91-XXXXXXXXXX

---

**Built with ❤️ for Uttarakhand**
