# Independent Driver — Complete Logic (A to Z)

**Last Updated:** 2026-06-11

---

## STEP 1: RIDE CREATE (Driver)

Driver app mein "Create Ride" tap karta hai.

### Checks (order mein):

| # | Check | Fail hone pe |
|---|-------|-------------|
| 1 | `cancel_blocked_until` check — driver blocked toh nahi? | "Bahut baar cancel kiya, kuch samay baad try karein" |
| 2 | `from_location` minimum 2 characters | 400 error |
| 3 | `to_location` minimum 2 characters | 400 error |
| 4 | from aur to same nahi hone chahiye | 400 error |
| 5 | `fare_per_seat` Rs.10 se Rs.10,000 ke beech | 400 error |
| 6 | Driver verified hai? (`driver_verification_requests` table, status=approved) | 403 — "Pehle verification complete karo" |
| 7 | `departure_time` future mein hona chahiye | 400 — "Past time nahi" |
| 8 | Departure minimum 2 hours aage | 400 — "2h advance chahiye" |
| 9 | Same driver ki same time pe koi aur ride overlap? | 400 — "Pehle wali complete/cancel karo" |

### Sab pass hone pe:

```
Trip created:
  status          = scheduled
  total_capacity  = vehicle_capacity (from verification)
  available_seats = total_capacity - 1  (seat 1 = driver)
  arrival_time    = departure + 2 hours
  created_source  = independent_driver
  require_approval = driver ki setting (default ON)
```

---

## STEP 2: RIDE DELETE (Driver, optional)

Driver galti se ride banaya toh delete kar sakta hai.

| # | Check | Fail hone pe |
|---|-------|-------------|
| 1 | Ride banaye 1 hour se zyada ho gaya? | "1 ghante ke andar hi delete hoti hai, cancel karo" |
| 2 | Koi booking hai (pending ya confirmed)? | "Bookings hain, delete nahi hoga" |

**Pass:** Trip DB se DELETE ho jaata hai (permanently, not cancelled). No penalty, no tracking.

---

## STEP 3: PASSENGER BOOKS SEAT

Passenger search karta hai, ride milti hai, seat select karta hai.

### Checks (order mein):

| # | Check | Fail hone pe |
|---|-------|-------------|
| 1 | `cancel_blocked_until` check — passenger blocked? | "Bahut baar cancel kiya" |
| 2 | Same trip pe 10 min pehle cancel kiya tha? (cooldown) | "X minute wait karo" |
| 3 | Trip exist karti hai aur status = scheduled? | 404 |
| 4 | Departure time abhi tak nahi guzra? | "Ride departed ho chuki" |
| 5 | Driver apni hi trip book nahi kar sakta | "Apni ride pe book nahi kar sakte" |
| 6 | Already is trip pe booking hai (pending/confirmed)? | "Already booked" |
| 7 | Independent driver ride pe passenger ka phone number hai? | "Pehle phone add karo profile mein" |
| 8 | Seat 1 select kiya? | "Seat 1 driver ki hai" |
| 9 | Seat number valid hai? (1 to total_capacity range) | "Invalid seat" |
| 10 | Seat already kisi ne book kiya? (pending ya confirmed) | "Seat X already booked" |
| 11 | available_seats enough hain? | "Itni seats nahi hain" |

### Sab pass hone pe — 2 cases:

**Case A: Driver ka `require_approval = ON` (default):**
```
Booking status = PENDING
Driver ko notification: "Approve karein"
Seats reserve ho jaati hain (available_seats - N)
```

**Case B: Driver ka `require_approval = OFF`:**
```
Booking status = CONFIRMED
confirmed_at = NOW
Dono ko notification: "Confirmed!"
Rate reminder scheduled (departure + 5 hours)
```

---

## STEP 4: DRIVER RESPONDS TO BOOKING

Driver ko notification aata hai — Accept ya Reject karo.

### Checks:

| # | Check | Fail hone pe |
|---|-------|-------------|
| 1 | Booking pending hai? | "Already processed" |
| 2 | Departure time nahi guzra? | "Time passed" |

### ACCEPT:

```
1. Seat conflict check:
   - Kisi aur ne same seat confirm karwa li?
   - Agar conflict: booking cancel, seats restore, error

2. Booking status = CONFIRMED, confirmed_at = NOW

3. Koi aur PENDING booking same seats pe?
   - Auto-cancel ho jaati hain
   - Unke seats restore
   - Unke passengers ko notification:
     "Your seats were given to another passenger"

4. Passenger ko notification: "Booking approved!"

5. Rate reminder scheduled (departure + 5h)
```

### REJECT:

```
1. Booking status = CANCELLED (no cancelled_at set)
2. Seats restore (+N)
3. Passenger ko notification: "Driver ne approve nahi ki"
4. Cancel tracking mein count NAHI hota (cancelled_at NULL)
5. No auto-rating (rejection is not a cancel)
```

---

## STEP 5A: DRIVER CANCELS RIDE

Driver "Cancel Trip" karta hai.

### Checks:

| # | Check | Fail hone pe |
|---|-------|-------------|
| 1 | `cancel_blocked_until` — blocked? | Vague message (no numbers) |
| 2 | Trip status = scheduled? | in_progress/completed/cancelled = error |
| 3 | Departure time nahi guzra? | "Ride start ho chuki" |

**NO time-based cutoff — kab bhi cancel karo departure se pehle (BlaBlaCar style)**

### Cancel hone pe:

```
1. ALL bookings (pending + confirmed) -> status = CANCELLED
   - cancellation_reason = "Driver cancelled the trip"
   - cancelled_at = NOW

2. Seats restore (sab ki seats wapas)

3. Trip status = CANCELLED

4. Sab passengers ko notification: "Driver ne ride cancel ki"

5. AUTO 1-STAR RATING (sirf confirmed bookings ke liye):
   - Har confirmed booking ke liye:
     ride_ratings INSERT
     from_role = 'passenger', rating = 1
     comment = "Auto-rating: Driver ne ride cancel ki."
     ON CONFLICT DO NOTHING
   - Pending bookings pe koi auto-rating nahi

6. Confirmed passengers ko RATE notification:
   "Driver ne cancel ki - apna experience share karein"

7. Rate reminders DELETE (cancelled bookings ke)
```

### Cancel Count Tracking (post-transaction):

```
TIER 1 - TEMP BLOCK:
  Count = cancelled trips in last 30 days
  Count >= SECRET threshold?
  YES -> cancel_blocked_until = NOW + 48 hours
  (Blocks: cancel + create rides)

TIER 2 - PERMANENT BLOCK:
  Count = cancelled trips in last 90 days
  Count >= SECRET threshold?
  YES -> cancel_blocked_until = 2099-12-31 (forever)
  (Account permanently blocked)
```

---

## STEP 5B: PASSENGER CANCELS BOOKING

Passenger "Cancel Booking" karta hai.

### Checks:

| # | Check | Fail hone pe |
|---|-------|-------------|
| 1 | `cancel_blocked_until` — blocked? | Vague message |
| 2 | Trip status in_progress ya completed nahi? | "Ride start ho chuki" |
| 3 | Departure time nahi guzra? | "Ride start ho chuki" |
| 4 | Booking already cancelled nahi? | "Already cancelled" |

**NO time-based cutoff — departure se pehle kab bhi cancel karo (BlaBlaCar style)**

### Cancel hone pe:

```
1. Reason sanitize:
   - User ne "auto-something" likha? "auto-" prefix strip hoga
   - Reason store hogi as-is (minus auto- prefix)

2. Booking status = CANCELLED
   - cancelled_at = NOW
   - cancellation_reason = user's reason (or NULL)

3. Seats restore (+N)

4. Driver ko notification: "Passenger ne cancel ki"

5. Rate reminder DELETE
```

### Cancel Count Tracking (sirf CONFIRMED cancel pe):

```
Pending booking cancel = NO PENALTY, no tracking at all.

Count query EXCLUDES:
  - auto-expired reasons (LIKE 'auto-%')
  - "Driver cancelled the trip"
  - "Cancelled by platform admin"
  Sirf passenger ki APNI cancellations count hoti hain

TIER 1 - TEMP BLOCK:
  Confirmed cancels in 30 days >= threshold?
  YES -> cancel_blocked_until = NOW + 24 hours

TIER 2 - PERMANENT BLOCK:
  Confirmed cancels in 90 days >= threshold?
  YES -> cancel_blocked_until = 2099-12-31 (forever)
```

### Auto 1-Star (sirf confirmed cancel pe):

```
ride_ratings INSERT
  from_role = 'driver', rating = 1
  comment = "Auto-rating: Passenger ne booking cancel ki."
  ON CONFLICT DO NOTHING

Driver ko RATE notification:
  "Passenger ne cancel ki - rate karein"
```

---

## STEP 6: RIDE AUTO-START (Cron - every 2 min)

`tripLifecycleJob` har 2 minute chalti hai.

```
Condition:
  departure_time <= NOW
  status = scheduled
  created_source = independent_driver

Action:
  1. Trip: scheduled -> IN_PROGRESS

  2. Pending bookings jo accept nahi hui?
     - status = CANCELLED
     - reason = "auto-expired-trip-started"
     - Seats restore
     - Passenger ko notification:
       "Driver ne confirm nahi ki, ride shuru ho gayi"

  3. CONFIRMED bookings: UNTOUCHED
     (passenger ride pe hai, booking theek hai)

  4. Driver ko notification: "Ride shuru ho gayi! Safe ride!"
```

---

## STEP 7: RIDE AUTO-COMPLETE (Cron - every 2 min)

Same `tripLifecycleJob`.

```
Condition:
  arrival_time <= NOW (= departure + 2 hours)
  status = in_progress
  created_source = independent_driver

Action:
  1. Trip: in_progress -> COMPLETED

  2. Confirmed bookings -> COMPLETED
     (ride khatam, safar poori)

  3. Leftover pending? (rare edge case)
     - status = CANCELLED
     - reason = "auto-expired-trip-completed"
     - Seats restore

  4. NO notification to driver (silent auto-complete)
```

---

## STEP 8: RATING FLOW

### 2 paths se rating aati hai:

**Path A - AUTO 1-STAR (instant, cancel pe):**
```
Cancel hone pe turant INSERT hota hai:
  rating = 1
  comment = "Auto-rating: ... cancel ki."
  ON CONFLICT DO NOTHING (duplicate protection)
```

**Path B - MANUAL RATING (user submits later):**
```
Rate notification departure + 5 hours pe aata hai.
Ya booking details screen se manually.
```

### Rating submit pe checks:

| # | Check | Result |
|---|-------|--------|
| 1 | Rating 1-5 integer? | 400 if invalid |
| 2 | Comment max 20 words? | 400 if over |
| 3 | Booking status = completed/confirmed/cancelled? | Pending = nahi |
| 4 | User is passenger or driver of this booking? | 403 if outsider |

### Agar cancelled booking hai — WHO cancelled?

| Cancellation Reason | Driver can rate? | Passenger can rate? |
|---------------------|-----------------|-------------------|
| "Driver cancelled the trip" | NO (canceller blocked) | YES |
| Passenger's own reason | YES | NO (canceller blocked) |
| "auto-expired-*" / "auto-*" | NO | NO (system action) |
| "platform admin" | NO | NO (admin action) |

### Auto-rating replacement:

```
Agar auto 1-star already hai (comment starts with "Auto-rating:"):
  - User ki manual rating se UPDATE ho jaata hai
  - User apna rating (1-5) + comment de sakta hai
  - Auto-rating replace ho jaati hai

Agar manual rating already hai:
  - "Already rated" error (ek baar manual rating di, dobara nahi)

Agar koi rating nahi:
  - New INSERT (fresh rating)
```

---

## STEP 9: AUTO CLEANUP & DELETE (Midnight IST daily)

`rideCleanupJob` raat ko 12:00 IST (18:30 UTC) pe chalta hai.

```
1. STALE PENDING BOOKINGS:
   - X hours purani pending bookings
   - Cancel, seats restore
   - Passenger notify: "Driver ne respond nahi kiya"

2. UNION TRIPS AUTO-COMPLETE:
   - Past arrival time union trips
   - Confirmed -> completed
   - Pending -> cancelled

3. OLD DATA DELETE (retention-based):
   - GPS history, SOS logs, login history
   - Contact logs, payments, complaints (resolved)
   - Driver verification docs, legacy reviews
   - Pending rate notifications

4. OLD TRIPS DELETE:
   - Completed/cancelled trips older than retention period
   - Bookings CASCADE delete with trip
   - ride_ratings KEPT forever (booking_id SET NULL)

5. FIFO CAPS:
   - Per-driver trip history limit
   - Per-user recent routes cap
   - Per-user ride_ratings cap
   - Broadcast total cap

6. MAINTENANCE:
   - VACUUM ANALYZE on high-churn tables
   - Expired refresh tokens cleaned
   - Expired OTPs cleaned
   - Old notifications deleted (read: 48h, unread: 168h)
   - Stale FCM tokens deleted
```

---

## CANCEL BLOCK SYSTEM (Summary)

```
                    +-------------+
                    | User cancels |
                    +------+------+
                           |
                    +------v------+
                    | Count check  |
                    | (30d window) |
                    +------+------+
                           |
                  +--------v--------+
             NO   | >= temp threshold|  YES
            +-----|                  |-----+
            |     +--------+--------+     |
            |              |              |
            v       +------v------+       v
        (tracked)   | Count check  |  TEMP BLOCK
                    | (90d window) |  (48h driver /
                    +------+------+   24h passenger)
                           |
                  +--------v--------+
             NO   | >= perm threshold|  YES
            +-----|                  |-----+
            |     +-----------------+     |
            v                             v
        (just temp                   PERMANENT BLOCK
         block applied)              (2099-12-31)
                                     Account forever blocked
```

### Block kya cover karta hai:

| Role | Block covers |
|------|-------------|
| Driver | Ride create BLOCKED + Ride cancel BLOCKED |
| Passenger | Booking create BLOCKED + Booking cancel BLOCKED |

### Kya count NAHI hota:

| Scenario | Why not counted |
|----------|----------------|
| Pending booking cancel | Low impact, no penalty |
| Auto-expired bookings (system) | System action, user ki galti nahi |
| "Driver cancelled the trip" bookings | Driver ki galti, passenger ki nahi |
| "Cancelled by platform admin" bookings | Admin action |
| Driver reject (booking) | Not a cancel by passenger |

### User ko kya dikhta hai:

```
Sirf vague message:
  "Bahut baar cancel kiya, kuch samay baad try karein"

NEVER shown:
  - Exact threshold numbers
  - Countdown timer
  - "X cancels remaining"
  - Block duration
  - Any specific number
```

---

## SEAT COUNTING

```
Trip create:
  total_capacity  = vehicle_capacity (e.g., 7)
  available_seats = total_capacity - 1 = 6
  (seat 1 = driver, permanently blocked for booking)

Booking:   available_seats -= N (seats reserved)
Cancel:    available_seats += N (seats restored)
Reject:    available_seats += N (seats restored)

Search filter: available_seats > 0 = trip dikhti hai
               available_seats = 0 = trip hidden (full)

Example (7-seat vehicle):
  Create:     available = 6 (seats 2-7 bookable)
  Book 2,3:   available = 4
  Book 4,5,6: available = 1
  Book 7:     available = 0 -> trip hidden from search
  Cancel 2,3: available = 2 -> trip visible again
```

---

## STATUS LIFECYCLE

```
TRIP:
  scheduled --> in_progress --> completed
       \                          |
        \--> cancelled            v
                              (DB cleanup after retention)

BOOKING:
  pending --> confirmed --> completed
       \         \              |
        \         \--> cancelled
         \--> cancelled     (DB cleanup after retention)
```

### Booking Status Transitions:

| From | To | Trigger |
|------|----|---------|
| pending | confirmed | Driver accepts |
| pending | cancelled | Driver rejects / passenger cancels / auto-expired / driver cancels trip |
| confirmed | completed | Trip auto-completes (arrival time reached) |
| confirmed | cancelled | Passenger cancels / driver cancels trip / admin cancels |
| completed | (final) | Cannot change |
| cancelled | (final) | Cannot change |

---

## NOTIFICATION SUMMARY

| Event | Who gets notified | Message |
|-------|------------------|---------|
| Booking created (pending) | Driver | "New booking request! Approve karein" |
| Booking created (confirmed) | Driver | "New booking confirmed!" |
| Booking accepted | Passenger | "Booking approved!" |
| Booking rejected | Passenger | "Driver ne approve nahi ki" |
| Passenger cancels | Driver | "Passenger ne cancel ki" |
| Driver cancels trip | All passengers | "Driver ne ride cancel ki" |
| Trip auto-started | Driver | "Ride shuru ho gayi! Safe ride!" |
| Pending auto-cancelled (trip start) | Passenger | "Driver ne confirm nahi ki, ride shuru ho gayi" |
| Seat conflict auto-cancel | Passenger | "Seats given to another passenger" |
| Cancel rating prompt | Affected party | "Rate your driver/passenger" |
| Rate reminder (5h after departure) | Both | "Rate your ride" |
| Rating received | Rated user | "New review received" |
