# LuhaRide — Independent Driver Complete Ride Lifecycle Flowchart

## Status Legend

```
Trip:    scheduled ──► in_progress ──► completed
                  \                         |
                   \──► cancelled            ▼
                                        (DB cleanup)

Booking: pending ──► confirmed ──► completed
              \          \              |
               \          \──► cancelled ▼
                \──► cancelled       (DB cleanup)
```

---

## PHASE 1: RIDE CREATION (Driver)

```
Driver taps "Create Ride"
        │
        ▼
┌─────────────────────────┐
│ cancel_blocked_until     │
│ check karo               │
└────────┬────────────────┘
         │
    ┌────▼────┐
    │ Blocked? │
    └────┬────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ "Xh   │   │
     │ tak    │   │
     │ ride   │   │
     │ nahi   │   │
     │ bana   │   │
     │ sakte" │   │
     └───────┘   │
                  ▼
┌─────────────────────────┐
│ Validation checks:       │
│ ☐ from_location (min 2)  │
│ ☐ to_location (min 2)    │
│ ☐ from ≠ to              │
│ ☐ fare ₹10 – ₹10,000    │
└────────┬────────────────┘
         │
    ┌────▼────────┐
    │ Any invalid? │
    └────┬────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ with  │   │
     │ reason│   │
     └───────┘   │
                  ▼
┌─────────────────────────┐
│ Driver verified check    │
│ (driver_verification_    │
│  requests table)         │
└────────┬────────────────┘
         │
    ┌────▼───────────┐
    │ Not verified?   │
    └────┬───────────┘
     YES │        NO
     ┌───▼───┐   │
     │ 403   │   │
     │ ERROR │   │
     └───────┘   │
                  ▼
┌─────────────────────────┐
│ Departure time check     │
│ Must be ≥ 2 hours ahead  │
│ (NOW + 2h minimum)       │
└────────┬────────────────┘
         │
    ┌────▼──────────────┐
    │ < 2h from now?     │
    └────┬──────────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ "2h   │   │
     │ adv"  │   │
     └───────┘   │
                  ▼
┌─────────────────────────┐
│ Overlap check:           │
│ Same driver, same time   │
│ window? (departure to    │
│ arrival overlap)         │
└────────┬────────────────┘
         │
    ┌────▼──────────┐
    │ Overlap found? │
    └────┬──────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ "time │   │
     │ clash"│   │
     └───────┘   │
                  ▼
┌─────────────────────────────────────┐
│ ✅ RIDE CREATED                      │
│                                      │
│ Trip status    = scheduled           │
│ total_seats    = vehicle capacity    │
│ available_seats= total - 1 (driver)  │
│ arrival_time   = departure + 2 hours │
│ created_source = independent_driver  │
└──────────────────────────────────────┘
```

---

## PHASE 2: RIDE DELETE (Driver, optional)

```
Driver taps "Delete Ride"
        │
        ▼
┌──────────────────────────┐
│ Check: created_at         │
│ vs NOW                    │
└────────┬─────────────────┘
         │
    ┌────▼────────────────┐
    │ > 1 hour since       │
    │ creation?            │
    └────┬────────────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ "1h   │   │
     │ window│   │
     │ over" │   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ Check: active bookings?   │
│ (pending or confirmed)    │
└────────┬─────────────────┘
         │
    ┌────▼──────────────┐
    │ Bookings exist?    │
    └────┬──────────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ "has  │   │
     │ book- │   │
     │ ings" │   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ ✅ RIDE DELETED            │
│ Trip removed from DB      │
│ (not cancelled, DELETED)  │
└───────────────────────────┘
```

---

## PHASE 3: PASSENGER BOOKS SEAT

```
Passenger taps "Book Seat"
        │
        ▼
┌──────────────────────────┐
│ cancel_blocked_until      │
│ check karo                │
└────────┬─────────────────┘
         │
    ┌────▼────┐
    │ Blocked? │
    └────┬────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ "Xh   │   │
     │ tak   │   │
     │ book  │   │
     │ nahi" │   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ Trip departure check      │
│ departure_time > NOW?     │
└────────┬─────────────────┘
         │
    ┌────▼──────────────┐
    │ Already departed?  │
    └────┬──────────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ "depa-│   │
     │ rted" │   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ Self-booking check        │
│ driver_id ≠ passenger_id  │
└────────┬─────────────────┘
         │
    ┌────▼────────────┐
    │ Own trip?        │
    └────┬────────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ Duplicate booking check   │
│ Already booked this trip? │
└────────┬─────────────────┘
         │
    ┌────▼──────────────┐
    │ Duplicate?         │
    └────┬──────────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ Phone number check        │
│ (independent driver ride  │
│  requires passenger phone)│
└────────┬─────────────────┘
         │
    ┌────▼──────────────┐
    │ No phone?          │
    └────┬──────────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ "add  │   │
     │ phone"│   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ Seat validation:          │
│ ☐ Valid seat numbers      │
│ ☐ No duplicates           │
│ ☐ Seat 1 blocked (driver) │
│ ☐ Seats available?        │
│ ☐ Seats not taken?        │
└────────┬─────────────────┘
         │
    ┌────▼──────────────┐
    │ Any seat issue?    │
    └────┬──────────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ Driver ka approval toggle │
│ require_approval setting  │
└────────┬─────────────────┘
         │
    ┌────▼────────────────┐
    │ Approval ON or OFF?  │
    └──┬──────────────┬───┘
       │              │
    ON ▼           OFF ▼
┌──────────┐  ┌──────────────┐
│ Booking  │  │ Booking      │
│ = PENDING│  │ = CONFIRMED  │
│          │  │ confirmed_at │
│ Driver   │  │ = NOW        │
│ ko notif │  │              │
│ "approve │  │ Dono ko notif│
│ karein"  │  │ "confirmed!" │
└──────────┘  └──────────────┘
       │              │
       ▼              ▼
┌──────────────────────────┐
│ Seats reserved (-N)       │
│ available_seats decreases │
│ Rate reminder scheduled   │
│ (departure + 5 hours)     │
└───────────────────────────┘
```

---

## PHASE 4: DRIVER RESPONDS TO BOOKING

```
Driver taps Accept/Reject
        │
        ▼
┌──────────────────────────┐
│ Is booking still pending? │
└────────┬─────────────────┘
         │
    ┌────▼──────────┐
    │ Not pending?   │
    └────┬──────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ Departure time passed?    │
└────────┬─────────────────┘
         │
    ┌────▼──────────┐
    │ Departed?      │
    └────┬──────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ "time │   │
     │ passed│   │
     └───────┘   │
                  ▼
    ┌─────────────────────┐
    │ Accept or Reject?    │
    └──┬──────────────┬───┘
       │              │
  ACCEPT▼         REJECT▼
       │              │
       ▼              ▼
┌──────────┐  ┌───────────────┐
│ Seat     │  │ Booking       │
│ conflict │  │ = CANCELLED   │
│ check    │  │               │
│ (already │  │ Seats restored│
│ taken?)  │  │ (+N)          │
└────┬─────┘  │               │
     │        │ Passenger ko  │
┌────▼────┐   │ notif:        │
│Conflict?│   │ "not approved"│
└──┬───┬──┘   └───────────────┘
YES│   │NO
   ▼   ▼
┌─────┐ ┌──────────────────┐
│Canc-│ │ Booking           │
│elled│ │ = CONFIRMED       │
│seats│ │ confirmed_at=NOW  │
│rest-│ │                   │
│ored │ │ Passenger notif:  │
└─────┘ │ "booking approved"│
        │                   │
        │ Other pending with│
        │ same seats?       │
        │ → auto-cancelled  │
        │ → seats restored  │
        │ → notified        │
        └───────────────────┘
```

---

## PHASE 5A: DRIVER CANCELS RIDE

```
Driver taps "Cancel Ride"
        │
        ▼
┌──────────────────────────┐
│ Trip status check         │
│ (only scheduled allowed)  │
└────────┬─────────────────┘
         │
    ┌────▼───────────────────┐
    │ in_progress/completed/  │
    │ cancelled?              │
    └────┬───────────────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ cancel_blocked_until      │
│ check                     │
└────────┬─────────────────┘
         │
    ┌────▼────┐
    │ Blocked? │
    └────┬────┘
     YES │        NO
     ┌───▼──────────────┐  │
     │ ERROR (vague msg) │  │
     │ "Bahut baar cancel│  │
     │  kiya, kuch samay │  │
     │  baad try karein" │  │
     └──────────────────┘  │
                  ▼
┌──────────────────────────────────────┐
│ NO time-based cutoff                  │
│ (BlaBlaCar style — cancel anytime     │
│  before departure, no grace period)   │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ ✅ TRIP CANCELLED                 │
│                                   │
│ Trip status = cancelled           │
│                                   │
│ ALL bookings (confirmed+pending)  │
│ → status = cancelled              │
│ → cancellation_reason =           │
│   "Driver cancelled the trip"     │
│                                   │
│ Seats restored (+N for all)       │
│                                   │
│ All passengers get notification:  │
│ "Driver ne ride cancel ki"        │
│                                   │
│ ⭐ AUTO 1-STAR RATING:            │
│ For each confirmed booking:       │
│ → INSERT ride_ratings             │
│   from_role = 'passenger'         │
│   rating = 1                      │
│   comment = 'Auto-rating:         │
│     Driver ne ride cancel ki.'    │
│   ON CONFLICT DO NOTHING          │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ CANCEL COUNT TRACKING (2 tiers)       │
│                                       │
│ ┌──────────────────────────────────┐  │
│ │ TIER 1: TEMP BLOCK               │  │
│ │ Count cancels in last 30 days    │  │
│ │ Count ≥ threshold?               │  │
│ │ YES → cancel_blocked_until       │  │
│ │        = NOW + 48 hours          │  │
│ │ NO  → just tracked              │  │
│ └──────────────────────────────────┘  │
│                                       │
│ ┌──────────────────────────────────┐  │
│ │ TIER 2: PERMANENT BLOCK          │  │
│ │ Count cancels in last 90 days    │  │
│ │ Count ≥ threshold?               │  │
│ │ YES → cancel_blocked_until       │  │
│ │        = 2099-12-31 (permanent)  │  │
│ │ NO  → just tracked              │  │
│ └──────────────────────────────────┘  │
│                                       │
│ ⚠ Exact thresholds are SECRET        │
│   (never shown to users)             │
└───────────────────────────────────────┘
```

---

## PHASE 5B: PASSENGER CANCELS BOOKING

```
Passenger taps "Cancel Booking"
        │
        ▼
┌──────────────────────────┐
│ cancel_blocked_until      │
│ check                     │
└────────┬─────────────────┘
         │
    ┌────▼────┐
    │ Blocked? │
    └────┬────┘
     YES │        NO
     ┌───▼──────────────┐  │
     │ ERROR (vague msg) │  │
     │ "Bahut baar cancel│  │
     │  kiya, kuch samay │  │
     │  baad try karein" │  │
     └──────────────────┘  │
                  ▼
┌──────────────────────────┐
│ Trip status check         │
│ in_progress / completed?  │
└────────┬─────────────────┘
         │
    ┌────▼──────────────┐
    │ Ride started/done? │
    └────┬──────────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     │ "ride │   │
     │ start │   │
     │ ho    │   │
     │ gayi" │   │
     └───────┘   │
                  ▼
┌──────────────────────────┐
│ Departure time passed?    │
│ NOW >= departure_time?    │
└────────┬─────────────────┘
         │
    ┌────▼────────┐
    │ Departed?    │
    └────┬────────┘
     YES │        NO
     ┌───▼───┐   │
     │ ERROR │   │
     └───────┘   │
                  ▼
┌──────────────────────────────────────┐
│ NO time-based cutoff                  │
│ (BlaBlaCar style — cancel anytime     │
│  before departure, no grace period)   │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│ ✅ BOOKING CANCELLED              │
│                                   │
│ Booking status = cancelled        │
│ cancelled_at = NOW                │
│ cancellation_reason = user reason │
│ (auto- prefix stripped if given)  │
│                                   │
│ Seats restored (+N)               │
│ available_seats increases          │
│                                   │
│ Driver gets notification:         │
│ "Passenger ne cancel ki"          │
│                                   │
│ ⭐ AUTO 1-STAR RATING:            │
│ → INSERT ride_ratings             │
│   from_role = 'driver'            │
│   rating = 1                      │
│   comment = 'Auto-rating:         │
│     Passenger ne booking          │
│     cancel ki.'                   │
│   ON CONFLICT DO NOTHING          │
│                                   │
│ Rate reminder deleted             │
└──────────────┬───────────────────┘
               │
               ▼
┌──────────────────────────────────────┐
│ CANCEL COUNT TRACKING (2 tiers)       │
│                                       │
│ Counts only user-initiated cancels    │
│ (COALESCE(reason,'') NOT LIKE 'auto-%')│
│                                       │
│ ┌──────────────────────────────────┐  │
│ │ TIER 1: TEMP BLOCK               │  │
│ │ Count cancels in last 30 days    │  │
│ │ Count ≥ threshold?               │  │
│ │ YES → cancel_blocked_until       │  │
│ │        = NOW + 24 hours          │  │
│ │ NO  → just tracked              │  │
│ └──────────────────────────────────┘  │
│                                       │
│ ┌──────────────────────────────────┐  │
│ │ TIER 2: PERMANENT BLOCK          │  │
│ │ Count cancels in last 90 days    │  │
│ │ Count ≥ threshold?               │  │
│ │ YES → cancel_blocked_until       │  │
│ │        = 2099-12-31 (permanent)  │  │
│ │ NO  → just tracked              │  │
│ └──────────────────────────────────┘  │
│                                       │
│ ⚠ Exact thresholds are SECRET        │
│   (never shown to users)             │
└───────────────────────────────────────┘
```

---

## PHASE 6: AUTO-LIFECYCLE (tripLifecycleJob — every 2 min)

```
┌─────────────────────────────────────────────┐
│            CRON JOB: Every 2 minutes         │
│         (with pg_advisory_lock)              │
└─────────────────┬───────────────────────────┘
                  │
    ══════════════▼══════════════
    ║  STEP A: AUTO-START       ║
    ║  departure_time <= NOW    ║
    ║  status = scheduled       ║
    ║  source = independent     ║
    ══════════════╤══════════════
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ Trip: scheduled ──► in_progress              │
│                                              │
│ Pending bookings found?                      │
│ ┌──────────────────────────────────────────┐ │
│ │ YES:                                     │ │
│ │ • All pending → cancelled                │ │
│ │ • reason = "auto-expired-trip-started"   │ │
│ │ • Seats restored (+N)                    │ │
│ │ • Each passenger notified:               │ │
│ │   "Driver ne confirm nahi ki,            │ │
│ │    ride shuru ho gayi"                   │ │
│ │                                          │ │
│ │ NO:                                      │ │
│ │ • Nothing extra                          │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ Confirmed bookings: UNTOUCHED (ride chal     │
│ rahi hai, passengers are on board)           │
│                                              │
│ Driver gets notification:                    │
│ "Ride shuru ho gayi! Safe ride!"             │
│                                              │
│ Socket emit: trip status = in_progress       │
└─────────────────────────────────────────────┘
                  │
    ══════════════▼══════════════
    ║  STEP B: AUTO-FINISH      ║
    ║  arrival_time <= NOW       ║
    ║  (= departure + 2 hours)  ║
    ║  status = in_progress     ║
    ║  source = independent     ║
    ══════════════╤══════════════
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ Trip: in_progress ──► completed              │
│                                              │
│ Confirmed bookings → completed               │
│ (ride ho gayi, safar khatam)                 │
│                                              │
│ Any leftover pending → cancelled             │
│ (reason = "auto-expired-trip-completed")     │
│ Seats restored                               │
│                                              │
│ ⚠ NO notification to driver                  │
│   (silent auto-complete)                     │
│                                              │
│ Socket emit: trip status = completed         │
└──────────────────────────────────────────────┘
```

---

## PHASE 7: RATING FLOW

```
┌─────────────────────────────────────────────────┐
│ TWO RATING PATHS:                                │
│                                                  │
│ A. AUTO 1-STAR (instant, on cancel)              │
│    → Inserted when someone cancels               │
│    → comment = "Auto-rating: ... cancel ki."     │
│    → ON CONFLICT DO NOTHING                      │
│                                                  │
│ B. MANUAL RATING (user submits later)            │
│    → Via rate notification (departure + 5h)      │
│    → Or from booking details screen              │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
          User opens rating screen
                    │
                    ▼
    ┌─────────────────────────┐
    │ Booking status check     │
    │ (completed or cancelled) │
    └────────┬────────────────┘
             │
        ┌────▼──────────────────────┐
        │ Status = pending?          │
        │ → ERROR "not ratable"      │
        │                            │
        │ Status = confirmed?        │
        │ → OK (legacy, still works) │
        │                            │
        │ Status = completed?        │
        │ → OK ✅ (normal flow)       │
        │                            │
        │ Status = cancelled?        │
        │ → see cancel rating rules  │
        └────────┬──────────────────┘
                 │
            (if cancelled)
                 │
                 ▼
    ┌─────────────────────────────┐
    │ WHO cancelled?               │
    │                              │
    │ ┌──────────────────────────┐ │
    │ │ Driver cancelled?        │ │
    │ │ → Driver CANNOT rate     │ │
    │ │ → Passenger CAN rate     │ │
    │ │                          │ │
    │ │ Passenger cancelled?     │ │
    │ │ → Passenger CANNOT rate  │ │
    │ │ → Driver CAN rate        │ │
    │ │                          │ │
    │ │ Auto-cancelled?          │ │
    │ │ → NOBODY can rate        │ │
    │ │   (auto-expired/system)  │ │
    │ └──────────────────────────┘ │
    └──────────────┬──────────────┘
                   │
                   ▼
    ┌──────────────────────────────────┐
    │ AUTO-RATING REPLACEMENT:          │
    │                                   │
    │ If auto 1-star already exists     │
    │ (comment starts with "Auto-      │
    │  rating:"):                       │
    │ → UPDATE with user's own rating   │
    │   and comment (replaces auto)     │
    │                                   │
    │ If manual rating already exists:  │
    │ → ERROR "already rated"           │
    │                                   │
    │ If no rating exists:              │
    │ → INSERT new rating               │
    └──────────────────────────────────┘
                   │
                   ▼
    ┌─────────────────────────────┐
    │ Rating submitted:            │
    │ • 1-5 stars                  │
    │ • Optional comment (20 max)  │
    │ • Stored in ride_ratings     │
    │ • Rated user gets notif:     │
    │   "New review received"      │
    │ • One rating per booking     │
    │   per role (no duplicates)   │
    └──────────────────────────────┘
```

---

## PHASE 8: CLEANUP & DB DELETE (midnight IST daily)

```
┌─────────────────────────────────────────────┐
│ rideCleanupJob — CRON: 18:30 UTC (midnight) │
│ (with pg_advisory_lock — one instance only)  │
└─────────────────┬───────────────────────────┘
                  │
    ══════════════▼══════════════
    ║  STEP 1: Stale Pending    ║
    ║  Bookings                 ║
    ══════════════╤══════════════
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ Pending bookings older than X hours?         │
│ YES → cancelled (auto-expired)               │
│     → seats restored                         │
│     → passenger notified:                    │
│       "Driver ne respond nahi kiya"          │
└─────────────────┬───────────────────────────┘
                  │
    ══════════════▼══════════════
    ║  STEP 2: Union Trips      ║
    ║  Auto-Complete             ║
    ══════════════╤══════════════
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ Union trips past arrival_time?               │
│ YES → status = completed                     │
│     → confirmed bookings → completed         │
│     → pending bookings → cancelled           │
└─────────────────┬───────────────────────────┘
                  │
    ══════════════▼══════════════
    ║  STEP 3: Dependent Data   ║
    ║  Purge (BEFORE trips)     ║
    ══════════════╤══════════════
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ Delete old data (retention-based):           │
│                                              │
│ • location_history (GPS)    → X days         │
│ • sos_logs                  → X days         │
│ • login_history             → X days         │
│ • contact_logs              → X days         │
│ • payments                  → X days         │
│ • complaints (resolved)     → X days         │
│ • driver_verification (done)→ X days         │
│ • driver_documents (legacy) → X days         │
│ • reviews (legacy)          → X days         │
│ • pending_rate_notifications→ X hours        │
└─────────────────┬───────────────────────────┘
                  │
    ══════════════▼══════════════
    ║  STEP 4: Trips + Bookings ║
    ║  Age-Based Delete          ║
    ══════════════╤══════════════
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ DELETE completed/cancelled trips             │
│ older than retention period                  │
│                                              │
│ Independent driver trips → X days            │
│ Union trips              → Y days            │
│                                              │
│ ⚠ Bookings CASCADE deleted with trip         │
│   (or already cleaned by FK)                 │
│                                              │
│ ⚠ ride_ratings NOT deleted                   │
│   (booking_id SET NULL, ratings kept forever)│
└─────────────────┬───────────────────────────┘
                  │
    ══════════════▼══════════════
    ║  STEP 5: FIFO Caps        ║
    ══════════════╤══════════════
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ Per-driver trip history cap:                 │
│ Keep only latest N trips per driver          │
│ (older ones deleted even if within age)      │
│                                              │
│ Per-user recent routes cap                   │
│ Per-user ride_ratings cap                    │
│ Broadcast total cap                          │
└─────────────────┬───────────────────────────┘
                  │
    ══════════════▼══════════════
    ║  STEP 6: Maintenance      ║
    ══════════════╤══════════════
                  │
                  ▼
┌─────────────────────────────────────────────┐
│ • VACUUM ANALYZE on high-churn tables        │
│   (trips, bookings, notifications,           │
│    location_history, login_history,          │
│    pending_rate_notifications,               │
│    union_daily_actions)                      │
│                                              │
│ • Expired refresh tokens cleaned             │
│ • Expired OTPs cleaned                       │
│                                              │
│ • Old notifications deleted:                 │
│   Read  → after X hours                     │
│   Unread→ after Y hours                     │
│                                              │
│ • Stale FCM tokens deleted                   │
└──────────────────────────────────────────────┘
```

---

## COMPLETE TIMELINE VIEW

```
TIME ──────────────────────────────────────────────────────────────────────►

DAY 1                          DAY 1                    DAY 1
10:00 AM                       4:00 PM                  6:00 PM
   │                              │                        │
   ▼                              ▼                        ▼
Driver creates ride          Passenger books          Driver approves
for 6 PM today               seat 2,3                booking
   │                              │                        │
   │ Trip: SCHEDULED              │ Booking: PENDING       │ Booking: CONFIRMED
   │ available: 6/7               │ available: 4/7         │
   │                              │                        │

DAY 1                          DAY 1                    DAY 1
6:00 PM                        6:02 PM                  8:00 PM
   │                              │                        │
   ▼                              ▼                        ▼
Departure time!              tripLifecycleJob          Arrival time!
                              auto-starts trip         tripLifecycleJob
   │                              │                     auto-finishes
   │                              │                        │
   │ Trip: IN_PROGRESS            │ Pending bookings       │ Trip: COMPLETED
   │                              │ → cancelled            │ Booking: COMPLETED
   │                              │ Confirmed: untouched   │

DAY 1                          DAY 2                    DAY X
11:00 PM                       midnight                    │
   │                              │                        │
   ▼                              ▼                        ▼
Rate notification            Next cleanup cycle        After retention
sent (departure+5h)          (nothing to clean yet)    period expires
   │                              │                        │
   │ Both can rate now            │                        │ Trip DELETED from DB
   │                              │                        │ Bookings DELETED
   │                              │                        │ Ratings KEPT (forever)
   │                              │                        │ 🏁 LIFECYCLE COMPLETE
```

---

## ANTI-GAMING RULES (Security)

```
┌──────────────────────────────────────────────┐
│ 1. Cancel reason sanitized                    │
│    User sends "auto-xyz" as reason            │
│    → "auto-" prefix stripped                  │
│    → counted as normal cancel                 │
│                                               │
│ 2. Driver block covers EVERYTHING              │
│    → Cannot cancel rides                      │
│    → Cannot CREATE new rides                  │
│    → Must wait until block expires            │
│    → Permanent block = forever (2099-12-31)   │
│                                               │
│ 3. Passenger block covers EVERYTHING          │
│    → Cannot cancel bookings                   │
│    → Cannot book new rides                    │
│    → Must wait until block expires            │
│    → Permanent block = forever (2099-12-31)   │
│                                               │
│ 4. NULL reason loophole FIXED                 │
│    → COALESCE(reason, '') NOT LIKE 'auto-%'   │
│    → Empty/null reasons still counted         │
│                                               │
│ 5. Pending cancel = NOT tracked               │
│    → Only confirmed cancel counts             │
│    → Pending cancel = low impact (OK)         │
│                                               │
│ 6. Duplicate booking blocked                  │
│    → Same trip, same passenger = ERROR        │
│                                               │
│ 7. Self-booking blocked                       │
│    → Driver cannot book own trip              │
│                                               │
│ 8. Auto 1-star on cancel (BlaBlaCar style)    │
│    → Canceller gets 1-star automatically      │
│    → Affected party can replace auto-rating   │
│      with their own manual rating + comment   │
│    → Canceller CANNOT submit any review       │
│                                               │
│ 9. Thresholds HIDDEN from users               │
│    → Vague messages only                      │
│    → No numbers, no countdown, no limit shown │
└───────────────────────────────────────────────┘
```

---

## CANCEL LIMITS SUMMARY (INTERNAL — NOT SHOWN TO USERS)

⚠ These thresholds are SECRET (BlaBlaCar style). User-facing messages
never reveal exact numbers. Only vague messages like "bahut baar cancel
kiya hai, kuch samay baad try karein."

No time-based cutoff — cancel anytime before departure (BlaBlaCar India model).

```
┌────────────┬────────────────┬────────────┬──────────────────┬───────────┐
│ Role       │ Time Cutoff    │ Temp Block │ Permanent Block  │ Auto-Rate │
├────────────┼────────────────┼────────────┼──────────────────┼───────────┤
│ Driver     │ NONE (anytime) │ SECRET/30d │ SECRET/90d       │ 1-star    │
│            │                │ → Xh block │ → forever block  │ each pax  │
│ Passenger  │ NONE (anytime) │ SECRET/30d │ SECRET/90d       │ 1-star    │
│            │                │ → Yh block │ → forever block  │ from dvr  │
└────────────┴────────────────┴────────────┴──────────────────┴───────────┘

Temp Block = account blocked for X/Y hours after exceeding threshold
Permanent Block = cancel_blocked_until = 2099-12-31 (effectively forever)
Auto-Rate = auto 1-star inserted on cancel, affected party can replace
```
