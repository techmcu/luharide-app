# 🚖 Phase 2: Booking System - Complete Plan

**Project:** LuhaRide  
**Phase:** 2 - Booking System  
**Timeline:** 2-3 weeks  
**Status:** 🚧 Ready to Start

---

## 🎯 Goal

Create a complete **seat-wise booking system** similar to RedBus/ZingBus but for shared taxis, with real-time seat availability and QR code verification.

---

## 📱 User Flow (After Login)

### **For Passengers:**

```
1. Home Screen
   ├── Search Box (From → To → Date)
   ├── Popular Routes (Quick access)
   ├── Recent Bookings
   └── Upcoming Trips

2. Search Results
   ├── List of available trips
   ├── Filters (Time, Price, Union)
   ├── Sort (Price, Time, Rating)
   └── Each trip shows:
       ├── Departure time
       ├── Route (From → To)
       ├── Available seats (e.g., 3/7)
       ├── Price per seat
       ├── Vehicle info
       ├── Driver rating
       └── Union name

3. Trip Details
   ├── Full route map
   ├── Stops along the way
   ├── Vehicle details (Number, Type)
   ├── Driver info (Name, Photo, Rating)
   ├── Amenities
   ├── Reviews
   └── "Book Now" button

4. Seat Selection
   ├── Visual seat layout (7-seater taxi)
   ├── Available seats (Green)
   ├── Booked seats (Red)
   ├── Your selection (Blue)
   ├── Select 1-4 seats
   └── Total price display

5. Passenger Details
   ├── Primary passenger (auto-filled from profile)
   ├── Additional passengers (if multiple seats)
   ├── Contact number
   ├── Emergency contact
   └── Special requests (optional)

6. Payment
   ├── Price breakdown
   ├── Payment methods:
   │   ├── Razorpay (UPI, Card, Wallet)
   │   ├── Cash (pay to driver)
   │   └── Wallet (future)
   └── Apply coupon (future)

7. Booking Confirmation
   ├── Booking ID
   ├── QR Code (for verification)
   ├── Trip details
   ├── Pickup point & time
   ├── Driver contact
   ├── "Share trip" button
   ├── "Cancel booking" button
   └── Add to calendar

8. My Bookings
   ├── Upcoming trips
   ├── Past trips
   ├── Cancelled trips
   └── Each booking shows:
       ├── Status badge
       ├── Trip details
       ├── QR code
       ├── Track button (if active)
       └── Actions (Cancel, Share, Review)
```

### **For Drivers:**

```
1. Home Screen
   ├── Today's trips
   ├── Upcoming trips
   ├── Earnings summary
   └── "Start trip" button

2. Trip Management
   ├── Trip details
   ├── Passenger list with QR codes
   ├── Scan QR to verify
   ├── Mark pickup/drop
   ├── Navigate to destination
   └── Complete trip

3. Earnings
   ├── Today's earnings
   ├── This week/month
   ├── Trip history
   └── Payout requests
```

---

## 🗂️ Database Schema (New Tables)

### **1. Routes Table** (Enhanced)
```sql
-- Already exists, may need enhancements
ALTER TABLE routes ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE routes ADD COLUMN IF NOT EXISTS estimated_duration INTEGER; -- in minutes
ALTER TABLE routes ADD COLUMN IF NOT EXISTS stops JSONB; -- array of stop names
```

### **2. Trips Table** (Enhanced)
```sql
-- Already exists, needs enhancements
ALTER TABLE trips ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'scheduled';
-- Status: scheduled, boarding, in_progress, completed, cancelled

ALTER TABLE trips ADD COLUMN IF NOT EXISTS available_seats INTEGER DEFAULT 7;
ALTER TABLE trips ADD COLUMN IF NOT EXISTS seat_layout JSONB;
-- Example: {"1": null, "2": "booking_id", "3": null, ...}

ALTER TABLE trips ADD COLUMN IF NOT EXISTS current_location JSONB;
-- {"lat": 30.xxx, "lng": 78.xxx, "timestamp": "..."}
```

### **3. Bookings Table** (Enhanced)
```sql
-- Already exists, needs enhancements
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS qr_code TEXT UNIQUE;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS seat_numbers INTEGER[];
-- Example: [2, 3] for seats 2 and 3

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS passengers JSONB;
-- Example: [{"name": "John", "age": 25, "gender": "M"}, ...]

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS pickup_location VARCHAR(255);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS drop_location VARCHAR(255);

ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS cancelled_by UUID REFERENCES users(id);

-- Status: pending, confirmed, completed, cancelled, refunded
```

### **4. New: Booking Passengers Table**
```sql
CREATE TABLE booking_passengers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) NOT NULL,
    name VARCHAR(100) NOT NULL,
    age INTEGER,
    gender VARCHAR(10),
    seat_number INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_booking_passengers_booking ON booking_passengers(booking_id);
```

### **5. New: Seat Locks Table** (Prevent double booking)
```sql
CREATE TABLE seat_locks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id UUID REFERENCES trips(id) NOT NULL,
    seat_number INTEGER NOT NULL,
    locked_by UUID REFERENCES users(id) NOT NULL,
    locked_until TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(trip_id, seat_number)
);

CREATE INDEX idx_seat_locks_trip ON seat_locks(trip_id);
CREATE INDEX idx_seat_locks_expires ON seat_locks(locked_until);
```

---

## 🔌 Backend API Endpoints

### **Routes Module**

```javascript
// Get popular routes
GET /api/routes/popular
Response: [
  {
    id: "uuid",
    from_location: "Dehradun",
    to_location: "Haridwar",
    base_fare: 300,
    trip_count: 15, // trips today
    avg_duration: 90 // minutes
  }
]

// Search routes
GET /api/routes/search?from=Dehradun&to=Haridwar
Response: [/* route objects */]
```

### **Trips Module**

```javascript
// Search available trips
GET /api/trips/search?route_id=uuid&date=2026-02-12
Query params:
  - route_id (required)
  - date (required, YYYY-MM-DD)
  - min_seats (optional, default 1)
  - sort (time|price|seats)
  
Response: [
  {
    id: "uuid",
    route: { from: "Dehradun", to: "Haridwar" },
    departure_time: "2026-02-12T08:00:00Z",
    arrival_time: "2026-02-12T09:30:00Z",
    available_seats: 5,
    total_seats: 7,
    fare_per_seat: 300,
    vehicle: {
      number: "UK01AB1234",
      type: "Sedan",
      model: "Toyota Innova"
    },
    driver: {
      id: "uuid",
      name: "Rajesh Kumar",
      rating: 4.5,
      total_trips: 250
    },
    union: {
      id: "uuid",
      name: "Dehradun Taxi Union"
    },
    status: "scheduled"
  }
]

// Get trip details
GET /api/trips/:id
Response: {
  /* full trip details */
  seat_layout: {
    "1": null,           // available
    "2": "booking_id",   // booked
    "3": null,
    "4": "booking_id",
    "5": null,
    "6": null,
    "7": null
  },
  stops: [
    { name: "Dehradun ISBT", time: "08:00" },
    { name: "Rajpur Road", time: "08:15" },
    { name: "Haridwar", time: "09:30" }
  ]
}
```

### **Booking Module**

```javascript
// Lock seats (temporary, 5 minutes)
POST /api/bookings/lock-seats
Body: {
  trip_id: "uuid",
  seat_numbers: [2, 3]
}
Response: {
  lock_id: "uuid",
  expires_at: "2026-02-12T08:05:00Z"
}

// Create booking
POST /api/bookings
Body: {
  trip_id: "uuid",
  seat_numbers: [2, 3],
  passengers: [
    { name: "John Doe", age: 30, gender: "M" },
    { name: "Jane Doe", age: 28, gender: "F" }
  ],
  pickup_location: "Dehradun ISBT",
  drop_location: "Haridwar",
  emergency_contact: "+919876543210",
  payment_method: "razorpay",
  lock_id: "uuid" // from previous lock
}
Response: {
  booking_id: "uuid",
  qr_code: "LR-20260212-ABCD1234",
  total_amount: 600,
  payment_required: true,
  razorpay_order_id: "order_xxx" // if payment_method is razorpay
}

// Get my bookings
GET /api/bookings/my-bookings?status=upcoming
Query params:
  - status: upcoming|past|cancelled|all
  - page, limit
Response: [/* booking objects with trip details */]

// Get booking details
GET /api/bookings/:id
Response: {
  id: "uuid",
  qr_code: "LR-20260212-ABCD1234",
  status: "confirmed",
  trip: {/* trip details */},
  passengers: [/* passenger list */],
  seat_numbers: [2, 3],
  total_amount: 600,
  payment_status: "paid",
  created_at: "...",
  can_cancel: true // based on trip time
}

// Cancel booking
POST /api/bookings/:id/cancel
Body: {
  reason: "Change of plans"
}
Response: {
  message: "Booking cancelled",
  refund_amount: 540, // 90% refund if >2 hours before trip
  refund_status: "pending"
}

// Verify QR code (Driver only)
POST /api/bookings/verify-qr
Body: {
  qr_code: "LR-20260212-ABCD1234"
}
Response: {
  valid: true,
  booking: {/* booking details */},
  passengers: [/* passenger list */]
}
```

---

## 📱 Mobile App Screens (Flutter)

### **Screen Structure:**

```
lib/screens/
├── home/
│   ├── home_screen.dart (✅ exists, needs enhancement)
│   ├── widgets/
│   │   ├── search_box.dart
│   │   ├── popular_routes_card.dart
│   │   ├── recent_bookings_card.dart
│   │   └── quick_actions.dart
│
├── search/
│   ├── search_screen.dart
│   ├── trip_list_screen.dart
│   ├── trip_details_screen.dart
│   └── widgets/
│       ├── trip_card.dart
│       ├── filter_bottom_sheet.dart
│       └── route_map.dart
│
├── booking/
│   ├── seat_selection_screen.dart
│   ├── passenger_details_screen.dart
│   ├── payment_screen.dart
│   ├── booking_confirmation_screen.dart
│   └── widgets/
│       ├── seat_layout.dart
│       ├── seat_widget.dart
│       ├── passenger_form.dart
│       └── price_breakdown.dart
│
├── bookings/
│   ├── my_bookings_screen.dart
│   ├── booking_details_screen.dart
│   └── widgets/
│       ├── booking_card.dart
│       ├── qr_code_display.dart
│       └── trip_timeline.dart
│
└── driver/ (for drivers)
    ├── driver_home_screen.dart
    ├── trip_management_screen.dart
    ├── qr_scanner_screen.dart
    └── earnings_screen.dart
```

### **Key Widgets to Create:**

1. **SearchBox** - From/To/Date selection
2. **TripCard** - Display trip in list
3. **SeatLayout** - Visual 7-seater layout
4. **QRCodeDisplay** - Show booking QR code
5. **TripTimeline** - Show trip progress
6. **FilterBottomSheet** - Filter trips
7. **PriceBreakdown** - Show price details

---

## 🎨 UI/UX Design Guidelines

### **Color Scheme:**
- **Primary:** Blue (#2196F3) - Trust, reliability
- **Secondary:** Green (#4CAF50) - Success, available
- **Accent:** Orange (#FF9800) - Actions, warnings
- **Error:** Red (#F44336) - Booked, errors
- **Background:** White/Light grey

### **Seat Colors:**
- 🟢 **Green** - Available
- 🔴 **Red** - Booked
- 🔵 **Blue** - Your selection
- ⚪ **Grey** - Disabled/Driver seat

### **Status Colors:**
- 🟡 **Yellow** - Pending
- 🟢 **Green** - Confirmed
- 🔵 **Blue** - In Progress
- ⚫ **Grey** - Completed
- 🔴 **Red** - Cancelled

---

## 🔐 Business Logic

### **Seat Locking Mechanism:**
1. User selects seats → Lock for 5 minutes
2. If payment not completed → Auto-release
3. If payment completed → Permanent booking
4. Prevent double booking with database locks

### **Cancellation Policy:**
```javascript
function calculateRefund(booking, currentTime) {
  const tripTime = booking.trip.departure_time;
  const hoursUntilTrip = (tripTime - currentTime) / (1000 * 60 * 60);
  
  if (hoursUntilTrip > 24) return 0.95; // 95% refund
  if (hoursUntilTrip > 12) return 0.90; // 90% refund
  if (hoursUntilTrip > 2) return 0.75;  // 75% refund
  return 0; // No refund if <2 hours
}
```

### **Pricing:**
- Base fare per seat (from routes table)
- No surge pricing (legal requirement)
- Optional: Discount coupons (future)

---

## ✅ Phase 2 Checklist

### **Week 1: Backend APIs**
- [ ] Enhance routes API
- [ ] Create trips search API
- [ ] Implement seat locking mechanism
- [ ] Create booking API with validation
- [ ] Add QR code generation
- [ ] Implement cancellation logic
- [ ] Add refund calculation
- [ ] Write unit tests

### **Week 2: Mobile UI (Passenger)**
- [ ] Enhance home screen with search
- [ ] Create trip list screen
- [ ] Build trip details screen
- [ ] Implement seat selection UI
- [ ] Create passenger details form
- [ ] Integrate payment gateway (Razorpay)
- [ ] Build booking confirmation screen
- [ ] Create my bookings screen
- [ ] Add QR code display

### **Week 3: Driver Features & Testing**
- [ ] Driver home screen
- [ ] Trip management screen
- [ ] QR scanner integration
- [ ] Passenger verification
- [ ] End-to-end testing
- [ ] Bug fixes
- [ ] Performance optimization
- [ ] Documentation

---

## 🎯 Success Criteria

### **Functional:**
- ✅ User can search and book trips
- ✅ No double booking possible
- ✅ QR code verification works
- ✅ Cancellation and refunds work
- ✅ Driver can manage trips

### **Non-Functional:**
- ✅ Booking completes in <30 seconds
- ✅ Search results load in <2 seconds
- ✅ 99% booking success rate
- ✅ Zero payment failures

---

## 📊 Sample Data Needed

### **For Testing:**
1. **10+ Routes** (popular Uttarakhand routes)
2. **50+ Trips** (next 7 days)
3. **5+ Unions** (registered taxi unions)
4. **20+ Vehicles** (with valid numbers)
5. **10+ Drivers** (with ratings)

### **Seed Data Script:**
```sql
-- Will create script: backend/seeds/002_trips_and_routes.sql
```

---

## 🚀 Ready to Start?

**Next Steps:**
1. Create database migration for new tables
2. Build backend APIs (routes, trips, bookings)
3. Create Flutter screens (search, booking flow)
4. Integrate Razorpay payment
5. Test end-to-end flow
6. Deploy and test on device

**Estimated Time:** 2-3 weeks  
**Priority:** High  
**Dependencies:** Phase 1 complete ✅

---

**Kya Phase 2 start kare?** 🚀
