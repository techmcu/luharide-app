# LuhaRide – Features & Flow (Easy Reference)

## Ride start time (Official)

- **Ride start time** = wohi time jo **driver ne ride create karte waqt daala** (departure time).  
  Ye `trips.departure_time` hai – isi se sab rules (rating, cancel) chalte hain.  
- “Start ride” button sirf status change karta hai (scheduled → in_progress); **start time change nahi hota**.

---

## Rating flow (Rating kab aur kaise)

1. **Booking confirm** – Jab driver booking accept karta hai (ya direct confirm), tab confirm hota hai.
2. **3 minutes baad** – Notification: “Rate your driver” / “Rate your passenger” (backend job).
3. **Rating kab submit** – Rating **confirm hone ke 4 minutes baad** se allow (ek hi bar):
   - `current time >= confirmed_at + 4 minutes` → rating submit ho sakti hai.
   - Isse pehle submit → error: “You can rate 4 minutes after your ride is confirmed. Please wait.”

**Backend:**  
- `bookings.confirmed_at`: jab status `confirmed` hota hai tab set.  
- `pending_rate_notifications`: `send_after` = confirm + 3 minutes.  
- Submit rating: `reviewService` me `confirmed_at + 4 min <= now` check.

**Frontend:**  
- Rate dialog: “You can rate 4 minutes after your ride is confirmed (one-time rating).”

---

## Cancel booking (Passenger)

- **Pending:** Hamesha cancel allow.  
- **Confirmed:** **Departure time se 2 minute pehle tak** cancel kar sakta hai; **uske baad** (yani departure ke 2 min ke andar) cancel **nahi** kar sakta.  
- Optional reason + driver ko notification.

**API:** `POST /api/bookings/:id/cancel` body `{ "reason": "optional" }`.

---

## Driver cancel trip – BlaBlaCar style

- Driver **poori trip cancel** kar sakta hai (sab bookings cancel, passengers ko notify).  
- **Rule:** Agar trip pe **confirmed passengers** hon **aur** departure se **2 hours** se kam time bacha ho, to driver **cancel nahi** kar sakta (passengers protect).  
- No confirmed bookings, ya departure 2+ hours door ho → driver cancel kar sakta hai.

**API:** `PUT /api/trips/:id/cancel` (Driver only).

---

## Trip status (Start / Complete ride)

- Driver apni trip pe:  
  - **Start ride** – status `scheduled` → `in_progress` (aur `started_at` set; rules ke liye start time = `departure_time`).  
  - **Complete ride** – status `in_progress` → `completed`.  
- **API:** `PUT /api/trips/:id/start`, `PUT /api/trips/:id/complete`.

---

## User bio & driver luggage

- **Bio:** Profile me 20 words tak short bio (API enforce).  
- **Luggage:** Driver “luggage per passenger” set karta hai (e.g. 1 bag, 2 bags); passenger ko trip/driver detail me dikhta hai.  
- **API:** `GET/PUT /api/auth/profile`, `GET /api/auth/me`; trip search/details me driver `bio`, `luggage_allowance_per_passenger`.

---

## Recent routes

- Search karte waqt from/to save ho jata hai (last 20 per user).  
- Search screen pe “Recent routes” chips – tap pe from/to fill.  
- **API:** `GET /api/trips/recent-routes`, `POST /api/trips/recent-routes` body `{ from_location, to_location }`.

---

## Share trip link

- Trip details screen pe Share menu → “Share trip link” ya “Copy link”.  
- Link: `{baseUrl}/trips/{tripId}`.

---

## Union admin dashboard

- Counts: total trips, total bookings, drivers verified.  
- **API:** `GET /api/union/dashboard` → `{ total_trips, total_bookings, drivers_verified }`.

---

## Database migrations

- **013** – Cancel (cancelled_at, reason), bio, luggage, recent_routes table.  
  Run: `node run-013-migration.js`  
- **014** – `trips.started_at` (optional; start time for rules = `departure_time`).  
  Run: `node run-014-migration.js`

---

## Summary table

| Feature              | When / Rule |
|----------------------|------------|
| Ride start time      | Always = driver-set `departure_time` |
| Rate notification    | 3 min after booking confirm |
| Submit rating        | Allowed **4 min after ride CONFIRM** (one-time) |
| Cancel (pending)     | Always |
| Cancel (confirmed)   | Until **2 min before departure**; uske baad cancel nahi |
| Driver cancel trip   | Not allowed if confirmed passengers + within 2h of departure |
| Start ride           | Driver → scheduled → in_progress |
| Complete ride        | Driver → in_progress → completed |
| Bio                  | Max 20 words in profile |
| Luggage              | Driver sets; shown to passenger |
| Recent routes        | Save on search; show chips on search screen |
| Share trip           | Trip details → Share / Copy link |
| Union dashboard      | Counts: trips, bookings, drivers verified |
