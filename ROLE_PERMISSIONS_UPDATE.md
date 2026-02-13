# 🔐 Role Permissions Update

## Changes Made

### Trip Creation Permissions

#### Before:
- ❌ Both `driver` and `union_admin` could create trips
- ❌ Confusing - union admin shouldn't create their own trips

#### After:
- ✅ **Individual Driver** (`role: driver`) - Can create their own trips
- ✅ **Union Admin** (`role: union_admin`) - Can create trips for drivers in their union (separate endpoint)

## API Endpoints

### For Individual Drivers:
```
POST /api/trips
Authorization: Bearer <driver_token>
Role Required: driver

Body:
{
  "from_location": "Dehradun",
  "to_location": "Haridwar",
  "departure_time": "2026-02-12T08:00:00Z",
  "fare_per_seat": 150,
  "vehicle_number": "UK 07 AB 1234",
  "total_seats": 7
}
```

### For Union Admins (Future):
```
POST /api/union/trips
Authorization: Bearer <union_admin_token>
Role Required: union_admin

Body:
{
  "driver_id": "uuid-of-driver-in-union",
  "from_location": "Dehradun",
  "to_location": "Haridwar",
  "departure_time": "2026-02-12T08:00:00Z",
  "fare_per_seat": 150,
  "vehicle_number": "UK 07 AB 1234",
  "total_seats": 7
}
```

## Files Modified

1. **`backend/src/routes/trips.js`**
   - Changed from `authorize(['driver', 'union_admin'])` 
   - To `authorize(['driver'])`
   - Only individual drivers can create trips via this endpoint

2. **`backend/src/controllers/unionTripController.js`** (NEW)
   - `createTripForDriver()` - Union admin creates trip for a driver
   - `getUnionTrips()` - Get all trips for union drivers

3. **`backend/src/routes/union.js`**
   - Added POST `/union/trips` - Create trip for driver
   - Added GET `/union/trips` - Get union trips
   - Requires `union_admin` role

## Testing

### Test as Individual Driver:
1. Login: `driver@demo.com` / `password123`
2. POST `/api/trips` - ✅ Should work
3. GET `/api/trips/my-trips` - ✅ Should work

### Test as Union Admin:
1. Login as union admin (when account exists)
2. POST `/api/trips` - ❌ Should fail (403 Forbidden)
3. POST `/api/union/trips` - ✅ Should work (with driver_id)
4. GET `/api/union/trips` - ✅ Should work

## Summary

**Individual Driver:**
- ✅ Create own trips
- ✅ View own trips
- ✅ Manage own schedule

**Union Admin:**
- ❌ Cannot create own trips (not a driver)
- ✅ Can create trips for drivers in union
- ✅ Can view all union trips
- ✅ Can manage union operations

---

**Status:** Updated
**Date:** February 11, 2026
