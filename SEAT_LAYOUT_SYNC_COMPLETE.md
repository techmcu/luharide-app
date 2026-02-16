# 🚗 Seat Layout Sync - Driver Verification = Passenger Booking

## 🎯 Requirement

**User:** "Jo driver verification ke time screen par show hota hai wahi passenger ko show ho ride book karte time. Har gadi ke hisaab se."

**Translation:** The seat layout shown during driver document verification (when driver selects their vehicle) should be the SAME layout shown to the passenger when booking a ride. Each vehicle has its own layout.

---

## ✅ Solution Implemented

### **Flow:**
```
Driver Verification (Become a Driver)
  → Select Brand: Mahindra
  → Select Model: Bolero 7-Seater
  → See seat layout (2,3,2 - 7 seats)
  → Submit → vehicle_model_id: "mahindra_bolero_suv" saved

Trip Creation
  → Backend copies vehicle_model_id from verification to trip

Passenger Booking
  → Opens seat selection
  → Uses trip.vehicle_model_id → VehicleCatalog.findModelById()
  → Shows SAME layout (2,3,2) as driver saw ✅
```

---

## 📂 Changes Made

### 1. **Migration 008** - New columns
**File:** `backend/migrations/008_vehicle_model_id.sql`
- `driver_verification_requests.vehicle_model_id` (VARCHAR 50)
- `trips.vehicle_model_id` (VARCHAR 50)

### 2. **Driver Verification - Backend**
**File:** `backend/src/controllers/driverVerificationController.js`
- Accepts `vehicle_model_id` in request body
- Stores in driver_verification_requests

### 3. **Driver Verification - Form**
**File:** `mobile/lib/screens/profile/driver_verification_form_screen.dart`
- Sends `vehicleModelId: _selectedModel?.id` when submitting
- e.g. "mahindra_bolero_suv", "mahindra_bolero_jeep" (10-seater)

### 4. **Driver Verification - Service**
**File:** `mobile/lib/services/driver_verification_service.dart`
- Added `vehicleModelId` parameter to submitVerification()

### 5. **Trip Creation - Backend**
**File:** `backend/src/controllers/tripController.js`
- Fetches `vehicle_model_id` from driver verification
- Stores in trips table when creating trip

### 6. **Trip Model**
**File:** `mobile/lib/models/trip_model.dart`
- Added `vehicleModelId` field
- Parsed from API response

### 7. **Seat Selection Screen**
**File:** `mobile/lib/screens/trips/seat_selection_screen.dart`
- **Before:** `VehicleCatalog.layoutForCapacity(totalSeats)` - generic by count
- **After:** `VehicleCatalog.findModelById(trip.vehicleModelId)?.layout ?? layoutForCapacity(totalSeats)`
- Uses EXACT vehicle layout when available
- Fallback to capacity-based layout for old trips

### 8. **Demo Driver & Fix Script**
- Added `vehicle_model_id: 'mahindra_bolero_suv'` to demo driver verification
- Fix script updates vehicle_model_id for existing records

---

## 🚗 Vehicle Layout Examples

| Vehicle | Model ID | Layout | Seats |
|---------|----------|--------|-------|
| Mahindra Bolero 7-Seater | mahindra_bolero_suv | [2,3,2] | 7 |
| Mahindra Bolero Jeep (Hill Taxi) | mahindra_bolero_jeep | [3,3,2,2] | 10 |
| Tata Sumo | tata_sumo | [2,3,3,2] | 9 |
| Maruti Ertiga | maruti_ertiga | [2,3,2] | 7 |
| Maruti Omni | maruti_omni | [2,3,3] | 8 |

---

## 🧪 Testing

### **Test 1: New Driver - Bolero 7-Seater**
```
1. Profile → Become a Driver
2. Brand: Mahindra, Model: Bolero 7-Seater
3. See layout: 2 front, 3 middle, 2 rear
4. Submit, get approved
5. Create trip
6. Passenger books → Sees SAME 2-3-2 layout ✅
```

### **Test 2: Bolero Jeep (10-seater)**
```
1. Driver verification: Mahindra → Bolero / Commander Jeep
2. See layout: 3-3-2-2 (different from 7-seater!)
3. Submit, approved, create trip
4. Passenger books → Seats in 3-3-2-2 pattern ✅
```

### **Test 3: Old Trips (before migration)**
```
- Trips without vehicle_model_id
- Seat selection falls back to layoutForCapacity(totalSeats)
- Still works, uses capacity-based layout
```

---

## 📋 Setup Steps

### **Run Migration First:**
```bash
cd D:\cur\luharide\backend
node run-008-migration.js
```

### **Fix Existing Drivers (optional):**
```bash
node fix-driver-verification-seats.js
```

### **Create Demo (refreshes demo driver):**
- Login screen → Create Demo
- Demo driver gets vehicle_model_id

---

## ✅ Result

**Driver verification layout = Passenger booking layout** ✅

- Mahindra Bolero 7-Seater → Same 2-3-2 layout both sides
- Bolero Jeep 10-seater → Same 3-3-2-2 layout
- Tata Sumo 9-seater → Same 2-3-3-2 layout
- Har gadi ka apna layout - exactly as driver chose! 🚗
