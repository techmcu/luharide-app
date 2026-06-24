# Rating & Cancel – Test Cases

## Kaise implement kiya (short)

1. **Rating – 4 min after CONFIRM**  
   - **Ride confirm** hone ke **4 minutes baad** rating kar sakte ho. Ek bar hi rating.  
   - `bookings.confirmed_at`: jab booking confirmed hoti hai (driver accept / ya direct confirm) tab set.  
   - `reviewService.submitRating`: `Date.now() >= confirmed_at + 4 * 60 * 1000`.  
   - Agar 4 min nahi guzre: *"You can rate 4 minutes after your ride is confirmed. Please wait."*

2. **Passenger cancel**  
   - **Departure time se 2 minute pehle tak** cancel kar sakta hai; **uske baad** cancel **nahi**.  
   - Check: `departure_time - now >= 2 minutes` → allow cancel.

4. **Driver cancel trip (BlaBlaCar style)**  
   - Naya: `PUT /api/trips/:id/cancel`.  
   - Agar trip pe **koi confirmed booking** hai **aur** `departure_time - now < 2 hours` → **reject**.  
   - Warna: trip status = `cancelled`, saari bookings cancelled, seats release, passengers ko notification.

5. **Mobile**  
   - Rate dialog me text: *"You can rate 4 minutes after the ride start time (departure time)."*

---

## Test cases

### Rating (4 min after CONFIRM)

| # | Scenario | Steps | Expected |
|---|----------|--------|----------|
| R1 | Rating before 4 min of confirm | Booking abhi confirm hui (confirmed_at = now). Turant rate bhejo. | **400** – "You can rate 4 minutes after your ride is confirmed. Please wait." |
| R2 | Rating 2 min after confirm | confirmed_at = 10:00, now = 10:02. Submit rating. | **400** – same message. |
| R3 | Rating 4 min after confirm | confirmed_at = 10:00, now = 10:05. Submit rating. | **201** – rating saved. |
| R4 | Rating long after confirm | Confirm hoye 1 din ho gaya; confirmed_at + 4 min already passed. | **201** – rating saved. |
| R5 | Already rated | Same booking pe dubara rate kare. | **400** – "You have already rated for this ride." |
| R6 | Wrong user | User A ki booking pe User B rate kare. | **403** – "You can only rate your own booking." |

**Manual / Postman:**  
- Koi bhi trip pe booking confirm karo (driver accept kare ya direct confirm).  
- Turant rate bhejo → R1 (400).  
- 4–5 min wait karke phir rate bhejo → R3 (201).

---

### Passenger cancel (2 min before departure)

| # | Scenario | Steps | Expected |
|---|----------|--------|----------|
| P1 | Pending cancel | Booking status = pending. Passenger cancels. | **200** – cancelled. |
| P2 | Confirmed, 1 hour before | departure_time = now + 1 hour. Passenger cancels. | **200** – cancelled; driver notified; seats released. |
| P3 | Confirmed, 1 min before | departure_time = now + 1 min. Passenger cancels. | **400** – "Cancellation not allowed. Cancel at least 2 minutes before departure." |
| P4 | Confirmed, exactly 2 min before | departure_time = now + 2 min. Passenger cancels. | **200** – cancelled (boundary allow). |
| P5 | Already cancelled | Booking already cancelled. Passenger cancels again. | **400** – "Booking is already cancelled." |
| P6 | Other user | User B tries to cancel User A’s booking. | **403** – "You can only cancel your own booking." |

**Manual:**  
- Trip with departure = ab se 5 min. Confirm booking.  
- Turant cancel karo → P3 (400).  
- Trip with departure = ab se 1 hour. Confirm. Cancel → P2 (200).

---

### Driver cancel trip (BlaBlaCar style)

| # | Scenario | Steps | Expected |
|---|----------|--------|----------|
| D1 | No confirmed bookings, 1 hour to departure | Trip has 0 confirmed bookings. departure = now + 1h. Driver cancels trip. | **200** – trip cancelled; no passengers to notify. |
| D2 | Confirmed booking, 3 hours to departure | 1 confirmed passenger. departure = now + 3h. Driver cancels. | **200** – trip cancelled; that booking cancelled; passenger notified; seats released. |
| D3 | Confirmed booking, 1 hour to departure | 1 confirmed passenger. departure = now + 1h. Driver cancels. | **400** – "Cannot cancel trip. You have 1 confirmed passenger(s). Driver cannot cancel within 2 hours of departure (BlaBlaCar-style)." |
| D4 | Confirmed booking, 5 min to departure | departure = now + 5 min. Driver cancels. | **400** – same as D3. |
| D5 | Only pending bookings, 1 hour to departure | Trip has only pending (no confirmed). Driver cancels. | **200** – trip cancelled; pending bookings cancelled. |
| D6 | Trip already completed | Trip status = completed. Driver calls cancel. | **400** – "Trip is already completed. Cannot cancel." |
| D7 | Other driver | Driver B calls cancel for Driver A’s trip. | **404** – "Trip not found." |

**Manual:**  
- Trip with departure = now + 1h, 1 confirmed booking → cancel → D3 (400).  
- Same trip but departure = now + 3h → cancel → D2 (200).  
- Trip with no confirmed bookings, departure = now + 30 min → cancel → D1 (200).

---

## Mobile – Driver cancel trip

- Driver trip details screen → App bar **⋮** menu → **Cancel trip (BlaBlaCar-style)**.  
- Confirm dialog ke baad `PUT /trips/:id/cancel` call. Success → back to list; failure → backend message (e.g. within 2h with confirmed passengers).  
- **Delete ride** option bhi same menu me (no bookings only).

---

## Quick checklist (release se pehle)

- [ ] Rating: 4 min after **confirm** – R1, R3 run karke verify.  
- [ ] Passenger cancel: departure se 2 min pehle tak allow; uske baad nahi – P2, P3, P4.  
- [ ] Driver cancel: 2h cutoff with confirmed – D2, D3.  
- [ ] Mobile: Rate dialog me "4 minutes after your ride is confirmed" text dikh raha hai.  
- [ ] Mobile: Driver trip details → ⋮ → Cancel trip → confirm → success/error.  
- [ ] Notifications: Driver cancel pe passenger ko "Ride cancelled" notification aata hai.
