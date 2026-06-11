# LuhaRide — Complete Testing SOP (Standard Operating Procedure)

**Last Updated:** 2026-06-11  
**Version:** 3.0 (Bug fixes: cancel fairness, rate notifications, Redis hardening)

---

## Part A: Auth & Account Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| A-001 | Signup new user | POST /auth/signup with valid email/password/name | 201, user created | P0 |
| A-002 | Duplicate email signup | POST /auth/signup with existing email | 409, blocked | P0 |
| A-003 | Login correct credentials | POST /auth/login with correct email/password | 200, tokens returned | P0 |
| A-004 | Login wrong password | POST /auth/login with wrong password | 401 | P0 |
| A-005 | Login non-existent user | POST /auth/login with unknown email | 401 | P1 |
| A-006 | Get profile with token | GET /auth/profile with valid JWT | 200, profile data | P0 |
| A-007 | Get profile without token | GET /auth/profile without header | 401 | P0 |
| A-008 | Get profile invalid token | GET /auth/profile with garbage token | 401 | P0 |
| A-009 | Update profile | PUT /auth/profile with name, phone | 200 | P1 |
| A-010 | Change password | PUT /auth/change-password | 200 | P1 |
| A-011 | Login with new password | POST /auth/login with changed password | 200 | P1 |
| A-012 | Forgot password OTP | POST /auth/forgot-password | 200 | P1 |
| A-013 | Logout | POST /auth/logout | 200 | P1 |
| A-014 | Token refresh | POST /auth/refresh with refresh token | 200, new access token | P0 |
| A-015 | Delete own account | DELETE /auth/account | 200 | P2 |

## Part B: Input Validation Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| B-001 | Invalid email format | Signup with "not-an-email" | 400 | P1 |
| B-002 | Short password | Signup with password < 6 chars | 400 | P1 |
| B-003 | Invalid role | Signup with role = "superadmin" | 400 | P1 |
| B-004 | Empty email/password login | Login with empty fields | 400 | P1 |
| B-005 | XSS in profile name | Update name with `<script>alert(1)</script>` | 200 (stored safely) | P1 |
| B-006 | SQL injection in login | Login email = `' OR 1=1 --` | 400 | P1 |
| B-007 | Invalid UUID in path | GET /trips/not-a-uuid | 400 | P2 |

## Part C: Security & Rate Limiting Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| C-001 | Brute force lock | 10 wrong passwords for same user | 429, account locked | P0 |
| C-002 | Login during lock | Correct password while locked | 429, still blocked | P0 |
| C-003 | Other user during lock | Different user login | 200 (not affected) | P1 |
| C-004 | IP rate limit | 30 failed logins from same IP | Rate limited | P1 |
| C-005 | Forgot password rate limit | Rapid forgot-password requests | Rate limited | P2 |

## Part D: RBAC / Cross-Role Access Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| D-001 | Passenger creates trip | POST /trips as passenger | 403 | P0 |
| D-002 | Passenger admin dashboard | GET /platform-admin/dashboard as passenger | 403 | P0 |
| D-003 | Driver admin users | GET /platform-admin/users as driver | 403 | P0 |
| D-004 | Passenger union dashboard | GET /unions/dashboard as passenger | 403 | P1 |
| D-005 | Driver union routes | GET /unions/routes as driver | 403 | P1 |
| D-006 | Union admin complaints | GET /platform-admin/complaints as union_admin | 403 | P1 |

## Part E: Passenger Flow Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| E-001 | Search rides | GET /trips/search?from=Dehradun&to=Purola | 200, array | P0 |
| E-002 | Search no results | GET /trips/search?from=XYZ&to=ABC | 200, empty | P1 |
| E-003 | Location autocomplete | GET /trips/locations?q=Deh | 200 | P1 |
| E-004 | View my bookings | GET /bookings/my | 200 | P0 |
| E-005 | View notifications | GET /notifications | 200 | P1 |
| E-006 | Mark all read | PUT /notifications/read-all | 200 | P2 |
| E-007 | Recent routes | GET /trips/recent-routes | 200 | P2 |
| E-008 | Save recent route | POST /trips/recent-routes | 200 | P2 |
| E-009 | View my reviews | GET /reviews/me | 200 | P1 |
| E-010 | Submit complaint | POST /complaints | 201 | P2 |
| E-011 | View complaints | GET /complaints/my | 200 | P2 |
| E-012 | Save FCM token | POST /notifications/fcm-token | 200 | P1 |

## Part F: Independent Driver — Trip & Booking Lifecycle

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| F-001 | Create trip | Driver POST /trips with from/to/departure/fare | 201, trip created | P0 |
| F-002 | Create trip — not verified | Unverified driver POST /trips | 403 | P0 |
| F-003 | Create trip — past departure | Departure time in past | 400 | P0 |
| F-004 | Create trip — empty from | from_location = "" | 400 | P1 |
| F-005 | Create trip — zero fare | fare_per_seat = 0 | 400 | P1 |
| F-006 | Create trip — same from/to | from_location = to_location | 400 | P1 |
| F-007 | View my trips | GET /trips/my | 200 | P0 |
| F-008 | View trip details | GET /trips/:id | 200 | P0 |
| F-009 | Get booked seats | GET /trips/:id/booked-seats | 200 | P1 |
| F-010 | Get trip bookings | GET /trips/:id/bookings | 200 | P1 |
| F-011 | Book seats (approval ON) | Passenger POST /bookings, driver require_approval=true | 201, status=pending | P0 |
| F-012 | Book seats (approval OFF) | Passenger POST /bookings, driver require_approval=false | 201, status=confirmed | P0 |
| F-013 | Book seat 1 (driver seat) | Book seat number 1 | 400 | P0 |
| F-014 | Book seat 99 (out of range) | Book seat > total_capacity | 400 | P1 |
| F-015 | Book empty seat array | POST /bookings with seats=[] | 400 | P1 |
| F-016 | Duplicate seat booking | Book already-taken seats | 400 | P0 |
| F-017 | Driver books own trip | Driver books on their own trip | 400 | P0 |
| F-018 | Book on cancelled trip | Book after trip cancelled | 404 | P1 |
| F-019 | Book on departed trip | Book after departure_time passed | 400 | P1 |
| F-020 | Driver accepts booking | PUT /bookings/:id/respond action=accept | 200, status=confirmed | P0 |
| F-021 | Driver rejects booking | PUT /bookings/:id/respond action=reject | 200, status=cancelled, seats restored | P0 |
| F-022 | Accept already-confirmed | Accept a confirmed booking | 400 | P1 |
| F-023 | Reject after departure | Respond to booking after trip departed | 400 | P1 |
| F-024 | Start trip (union/legacy) | PUT /trips/:id/start for union trip | 200, status=in_progress | P0 |
| F-025 | Start independent driver trip before departure | PUT /trips/:id/start for independent_driver before departure_time | 400, "Independent rides auto-start at departure time" | P0 |
| F-026 | Delete empty trip | DELETE /trips/:id (no bookings) | 200 | P1 |
| F-027 | Delete trip with bookings | DELETE /trips/:id (active bookings) | 400 | P0 |
| F-028 | Complete trip from in_progress | PUT /trips/:id/complete when status=in_progress | 200, status=completed | P0 |
| F-029 | Complete trip from scheduled (blocked) | PUT /trips/:id/complete when status=scheduled | 400, "Only in-progress trips can be completed" | P0 |
| F-030 | Complete trip before departure | PUT /trips/:id/complete before departure_time | 400, "Cannot complete ride before departure time" | P1 |

## Part G: BlaBlaCar-Style Cancel Rules (Independent Driver)

### G1: Driver Cancel

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| G-001 | Driver cancels trip (no bookings) | Cancel scheduled trip with 0 bookings | 200, trip cancelled, no penalty | P0 |
| G-002 | Driver cancels trip (with confirmed bookings) | Cancel trip with confirmed passengers | 200, all bookings cancelled, reason="Driver cancelled the trip", seats restored | P0 |
| G-003 | Driver cancels trip (with pending bookings) | Cancel trip with pending-only bookings | 200, pending bookings cancelled, seats restored | P0 |
| G-004 | Driver cancels trip (mixed pending+confirmed) | Cancel trip with both types | 200, ALL bookings cancelled, seats = total restored | P0 |
| G-005 | Cancel anytime before departure | Cancel 1 minute before departure_time | 200, allowed (no time cutoff) | P0 |
| G-006 | Cancel 24h before departure | Cancel well in advance | 200, allowed | P1 |
| G-007 | Cancel just after creation | Cancel within seconds of creating trip | 200, allowed (no grace period needed) | P1 |
| G-008 | Cannot cancel in_progress trip | Cancel after trip status=in_progress | 400 | P0 |
| G-009 | Cannot cancel completed trip | Cancel after trip status=completed | 400 | P0 |
| G-010 | Cannot cancel already cancelled | Cancel same trip twice | 400 | P1 |
| G-011 | Passengers notified on cancel | Cancel trip with passengers → check notifications | All passengers get notification (type=trip_cancelled). Body in user's language (EN or HI via app localization) | P0 |
| G-012 | Auto 1-star on driver (confirmed booking) | Driver cancels trip with confirmed booking | ride_ratings row inserted: from_role=passenger, rating=1, comment="Auto-rating: Driver cancelled the ride." | P0 |
| G-013 | Auto 1-star per confirmed booking | Driver cancels trip with 3 confirmed bookings | 3 auto-1-star ratings inserted (one per booking) | P1 |
| G-014 | No auto-rating for pending bookings | Cancel trip, check pending booking passengers | No auto-rating for pending-only passengers | P1 |

### G2: Passenger Cancel

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| G-020 | Passenger cancels confirmed booking | Cancel a confirmed booking | 200, booking cancelled, seats restored | P0 |
| G-021 | Passenger cancels pending booking | Cancel a pending booking | 200, booking cancelled, seats restored | P0 |
| G-022 | Cancel anytime before departure | Cancel 1 minute before departure | 200, allowed | P0 |
| G-023 | Cancel well in advance | Cancel 24h before departure | 200, allowed | P1 |
| G-024 | Cannot cancel after departure | Cancel after departure_time passed | 400, "Ride has already started" | P0 |
| G-025 | Cannot cancel in_progress ride | Cancel when trip status=in_progress | 400 | P0 |
| G-026 | Cannot cancel completed ride | Cancel when trip status=completed | 400 | P1 |
| G-027 | Cannot cancel already cancelled | Cancel same booking twice | 400 | P1 |
| G-028 | Driver notified on cancel | Cancel confirmed booking → check driver notification | Driver gets notification (type=booking_cancelled). Body in user's language | P0 |
| G-029 | Auto 1-star on passenger | Passenger cancels confirmed booking | ride_ratings: from_role=driver, rating=1, comment="Auto-rating: Passenger cancelled the booking." | P0 |
| G-030 | Cancel reason stored | Cancel with reason="plan changed" | cancellation_reason = "plan changed" | P1 |
| G-031 | Auto-prefix stripped | Cancel with reason="auto-something" | cancellation_reason = "something" (auto- removed) | P1 |
| G-032 | Null reason handled | Cancel with no reason | cancellation_reason = null, still counted | P1 |

### G3: Cancel Block (Temp + Permanent)

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| G-040 | Driver temp block triggers | Cancel trips repeatedly until temp threshold | cancel_blocked_until set (NOW + 48h) | P0 |
| G-041 | Blocked driver cannot create trip | Create trip while cancel_blocked_until > NOW | 403/400, vague message (no threshold shown) | P0 |
| G-042 | Blocked driver cannot cancel | Cancel trip while blocked | 400, vague message | P1 |
| G-043 | Block expires after time | Wait until cancel_blocked_until passes → create trip | 201, allowed | P1 |
| G-044 | Driver permanent block | Cancel excessively in 90 days until permanent threshold | cancel_blocked_until = 2099-12-31 | P0 |
| G-045 | Permanent block is forever | Try to create trip with blocked_until = 2099 | Blocked permanently | P0 |
| G-046 | Passenger temp block triggers | Cancel bookings repeatedly until threshold | cancel_blocked_until set (NOW + 24h) | P0 |
| G-047 | Blocked passenger cannot book | Book while cancel_blocked_until > NOW | 400, vague message | P0 |
| G-048 | Passenger permanent block | Cancel excessively in 90 days | cancel_blocked_until = 2099-12-31 | P0 |
| G-049 | Vague error messages only | Check error text when blocked | Must NOT contain numbers, thresholds, or countdown | P0 |
| G-050 | Only user-initiated cancels counted | Check that auto-expired cancels (reason starts with "auto-") don't count | Cancel count excludes auto-reasons | P1 |
| G-051 | Admin cancel does NOT count against driver | Admin cancels driver's trip → check driver cancel count | trips.cancelled_by = 'admin', NOT counted in cancel tracking query | P0 |
| G-052 | Driver cancel sets cancelled_by = 'driver' | Driver cancels own trip → check trips table | cancelled_by = 'driver' | P0 |
| G-053 | Admin cancel sets cancelled_by = 'admin' | Admin cancels trip via platform admin → check trips table | cancelled_by = 'admin' | P0 |
| G-054 | Rejected booking has no cancelled_at | Driver rejects pending booking → check bookings table | status = 'cancelled', cancelled_at = NULL, not counted in passenger cancel tracking | P1 |

## Part H: Rating & Review (BlaBlaCar-Style)

### H1: Normal Rating Flow

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| H-001 | Rate after completed ride | Complete ride → submit rating (1-5 stars) | 201 | P0 |
| H-002 | Rate with comment | Submit rating + comment (under 20 words) | 201, comment stored | P0 |
| H-003 | Rate value 0 (below min) | Submit rating = 0 | 400 | P1 |
| H-004 | Rate value 6 (above max) | Submit rating = 6 | 400 | P1 |
| H-005 | Duplicate manual rating | Rate same booking twice | 400, "already rated" | P0 |
| H-006 | Rate confirmed booking (legacy) | Rate booking with status=confirmed | 201 (still works) | P2 |
| H-007 | Rate pending booking | Rate pending booking | 400 | P1 |
| H-008 | Rate other's booking | Rate booking you're not part of | 403 | P1 |
| H-009 | Comment over 20 words | Submit comment with 25 words | 400 | P2 |
| H-010 | Rated user gets notification | Submit rating → check rated user's notifications | "New review received" notification | P1 |

### H2: Cancel Rating Flow

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| H-020 | Driver cancels → passenger CAN rate | Driver cancels trip → passenger submits rating | 201, rating accepted | P0 |
| H-021 | Driver cancels → driver CANNOT rate | Driver cancels trip → driver tries to rate | 400, "You cancelled the ride — you cannot rate." | P0 |
| H-022 | Passenger cancels → driver CAN rate | Passenger cancels → driver submits rating | 201, rating accepted | P0 |
| H-023 | Passenger cancels → passenger CANNOT rate | Passenger cancels → passenger tries to rate | 400, "You cancelled the booking — you cannot rate." | P0 |
| H-024 | Auto-cancelled → nobody rates | Auto-expired booking → anyone tries to rate | 400, "Auto-cancelled bookings cannot be rated" | P0 |
| H-025 | Auto-rating replaced by manual | Passenger cancels → auto-1-star on passenger → driver submits 3-star with comment | Driver's rating replaces auto-1-star (comment no longer starts with "Auto-rating:") | P0 |
| H-026 | Auto-rating replacement keeps booking_id | After replacing auto-rating → check ride_ratings table | Same row updated, same id, same booking_id | P1 |
| H-027 | Cannot replace manual rating | Driver submits manual rating → tries to submit again | 400, "already rated" | P1 |

## Part I: Booking Status Lifecycle

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| I-001 | Booking pending → confirmed (accept) | Driver accepts pending booking | status = confirmed | P0 |
| I-002 | Booking confirmed → completed (ride ends) | Trip completes via auto-lifecycle | Confirmed bookings → status = completed | P0 |
| I-003 | Booking pending → cancelled (reject) | Driver rejects booking | status = cancelled | P0 |
| I-004 | Booking pending → cancelled (auto-start) | Trip auto-starts, pending bookings not accepted | status = cancelled, reason = "auto-expired-trip-started" | P0 |
| I-005 | Booking pending → cancelled (auto-complete) | Trip auto-completes, leftover pending | status = cancelled, reason = "auto-expired-trip-completed" | P1 |
| I-006 | Booking confirmed → cancelled (driver cancel) | Driver cancels trip | All confirmed → cancelled, reason = "Driver cancelled the trip" | P0 |
| I-007 | Booking confirmed → cancelled (passenger cancel) | Passenger cancels own booking | status = cancelled | P0 |
| I-008 | Completed booking visible in UI | Check "My Rides" screen | Completed booking shows teal color, "Completed" / "Purihooi" text | P1 |
| I-009 | Completed booking — no cancel button | Check UI for completed booking | Cancel button hidden | P1 |
| I-010 | Driver contact visible for completed booking | GET /bookings/my → check completed booking | driver object present (name, phone, whatsapp) — NOT null | P0 |
| I-011 | Passengers notified on auto-complete | Trip auto-completes (arrival_time reached) → check passenger notifications | Notification type=trip_completed, title="Ride completed!", body="Rate your experience!" | P0 |
| I-012 | Rate notification sent for completed rides | Ride completes → wait 5h after departure → check rate_ride notification | Notification sent (status check includes 'completed', not just 'confirmed') | P0 |
| I-013 | Rate notification NOT sent for cancelled rides | Ride cancelled → pending_rate_notifications deleted | No rate_ride notification sent | P1 |

## Part J: Union Flow Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| J-001 | Get union info | GET /unions/me | 200 | P0 |
| J-002 | Union dashboard stats | GET /unions/dashboard | 200 | P0 |
| J-003 | Add route | POST /unions/routes | 201 | P0 |
| J-004 | View routes | GET /unions/routes | 200 | P1 |
| J-005 | Add driver | POST /unions/drivers | 201 | P0 |
| J-006 | View drivers | GET /unions/drivers | 200 | P1 |
| J-007 | Bulk schedule (1st) | POST /unions/schedules/bulk | 201 | P0 |
| J-008 | Bulk schedule (2nd) | POST /unions/schedules/bulk | 201 | P1 |
| J-009 | Bulk schedule (3rd) | POST /unions/schedules/bulk | 201 | P1 |
| J-010 | 4th bulk blocked (daily limit) | POST /unions/schedules/bulk 4th time | 400 | P0 |
| J-011 | Cancel schedule (within 1h) | DELETE /unions/schedules/:id within 1 hour | 200 | P1 |
| J-012 | Update branding | PUT /unions/branding | 200 | P2 |
| J-013 | Log driver contact | POST /unions/contact-log | 200 | P2 |
| J-014 | Contact stats | GET /unions/contact-stats | 200 | P2 |
| J-015 | Delete route | DELETE /unions/routes/:id | 200 | P2 |
| J-016 | Union directory | GET /unions/directory (admin) | 200 | P2 |

## Part K: Admin Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| K-001 | Admin dashboard | GET /platform-admin/dashboard | 200 | P0 |
| K-002 | Users list | GET /platform-admin/users | 200 | P0 |
| K-003 | Search users | GET /platform-admin/users?search=test | 200 | P1 |
| K-004 | User detail | GET /platform-admin/users/:id | 200 | P1 |
| K-005 | Trips list | GET /platform-admin/trips | 200 | P0 |
| K-006 | Trip detail | GET /platform-admin/trips/:id | 200 | P1 |
| K-007 | Admin cancel trip | PUT /platform-admin/trips/:id/cancel | 200 | P0 |
| K-008 | Revenue stats | GET /platform-admin/revenue | 200 | P1 |
| K-009 | Daily stats | GET /platform-admin/daily-stats | 200 | P1 |
| K-010 | Export CSV | GET /platform-admin/export | 200 | P2 |
| K-011 | Complaints list | GET /platform-admin/complaints | 200 | P1 |
| K-012 | Resolve complaint | PUT /platform-admin/complaints/:id/resolve | 200 | P2 |
| K-013 | Broadcast notification | POST /platform-admin/notifications/broadcast | 200 | P1 |
| K-014 | FCM settings | GET /platform-admin/fcm-settings | 200 | P2 |
| K-015 | Global FCM toggle | PUT /platform-admin/fcm-toggle | 200 | P2 |
| K-016 | Disable user | PUT /platform-admin/users/:id/disable | 200 | P0 |
| K-017 | Disabled login blocked | Login as disabled user | 401 | P0 |
| K-018 | Re-enable user | PUT /platform-admin/users/:id/enable | 200 | P1 |

## Part L: Notification Localization Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| L-001 | Backend sends English notification body | Trigger any notification (cancel, reject, rate) → read DB | Body text is proper English (no Hinglish) | P0 |
| L-002 | Flutter shows English (EN mode) | Set app to English → open Notifications screen | All notification titles/bodies in English | P0 |
| L-003 | Flutter shows Hindi (HI mode) | Set app to Hindi → open Notifications screen | Known notification types show Hindi title/body | P0 |
| L-004 | Unknown type fallback | Backend sends notification with new/unknown type | Flutter shows raw backend English text (no crash) | P1 |
| L-005 | Booking rejected notification localized | Reject a booking → check passenger notification in Hindi | Title: "बुकिंग स्वीकृत नहीं हुई", Body: Hindi text | P1 |
| L-006 | Rate ride notification localized | Trigger rate reminder → check notification in Hindi | Title: "अपनी राइड को रेट करें", Body: Hindi text | P1 |
| L-007 | Trip auto-started notification localized | Wait for trip auto-start → check driver notification in Hindi | Title: "आपकी राइड शुरू हो गई!", Body: Hindi text | P1 |
| L-008 | Cancel rating prompt localized | Driver cancels trip → passenger sees rate prompt in Hindi | Hindi body shown | P1 |
| L-009 | FCM push stays Hinglish/English | Trigger FCM push → check system notification tray | FCM text unchanged (backend English or Hinglish for SMS/FCM) — acceptable | P2 |
| L-010 | No Hinglish in any API error response | Hit all error cases (blocked, invalid, etc.) | All error messages are proper English | P0 |
| L-011 | Trip completed notification localized | Trip auto-completes → check notification in Hindi mode | Title: "राइड पूरी हो गई!", Body: "आपकी राइड पूरी हो गई है। अपना अनुभव रेट करें!" | P1 |

## Part M: Infrastructure & Health

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| M-001 | Public search (no auth) | GET /trips/search without token | 200 | P0 |
| M-002 | Public locations (no auth) | GET /trips/locations without token | 200 | P0 |
| M-003 | Health check | GET /health | 200, includes redis.memory and redis.keys | P0 |
| M-004 | Auth service ping | GET /auth/ping | 200 | P1 |
| M-005 | Redis health in health endpoint | GET /health → check redis object | redis.up=true, redis.memory shows usage, redis.keys shows count | P1 |
| M-006 | Redis maxmemory configured | redis-cli CONFIG GET maxmemory on VPS | Value > 0 (e.g. 100mb), policy = allkeys-lru | P0 |
| M-007 | Redis auto-restart on crash | sudo systemctl show redis-server \| grep Restart | Restart=always, RestartSec=5 | P0 |
| M-008 | Redis fallback on failure | Stop Redis → hit API endpoints | Rate limiting falls back to in-memory, app doesn't crash | P1 |
| M-009 | Redis recovery alert | Stop then start Redis → check Telegram | DOWN alert on stop, RECOVERED alert on restart | P1 |

---

# Testing Types Guide — Priority Order

## 1. Functional Testing (P0 — FIRST)

**What:** Every feature works correctly. All API endpoints return expected responses.  
**Tools:**  
- **Postman** — manual API testing, collection runner, environment variables  
- **Thunder Client** (VS Code extension) — lightweight Postman alternative  
- **curl / httpie** — terminal-based API calls  
- **Custom Node.js scripts** — automated test suites (like full-test.js)

**How to tell tester:**  
"Har ek API endpoint ko test karo — correct input, wrong input, edge cases. Postman collection banao. Expected vs actual compare karo. P0 test cases pehle karo."

---

## 2. Integration Testing (P0 — WITH Functional)

**What:** Full end-to-end flows work together. Trip create → book → accept → ride complete → rating.  
**Tools:**  
- **Postman Collection Runner** — chain requests, pass variables between steps  
- **Jest + Supertest** — automated backend integration tests (already 208 tests)  
- **Custom scripts** — lifecycle test scripts

**How to tell tester:**  
"Pura flow test karo — ek ride create karo, booking karo, accept karo, ride complete hone do, rating do. Beech mein koi step fail nahi hona chahiye. Cancel flow bhi pura test karo."

---

## 3. Security Testing (P0 — WITH Functional)

**What:** No unauthorized access, no injection attacks, brute force protection works.  
**Tools:**  
- **Postman** — manual RBAC, token, injection tests  
- **OWASP ZAP** (free) — automated vulnerability scanning  
- **Burp Suite** (Community Edition, free) — intercept & modify requests  
- **sqlmap** — SQL injection testing (use carefully, only on your own server)

**How to tell tester:**  
"SQL injection try karo login mein, XSS profile name mein, token bina API call karo, wrong role se admin endpoint hit karo. 10 baar galat password daalo — lock hona chahiye."

---

## 4. UI/UX Testing (P1 — After API verified)

**What:** All screens look correct, buttons work, text readable, no overflow, language switch works.  
**Tools:**  
- **Physical device** — real phone testing (best)  
- **Android Emulator** — Android Studio built-in  
- **iOS Simulator** — Xcode (Mac only)  
- **BrowserStack / LambdaTest** — cloud device testing (paid)  
- **Flutter DevTools** — widget inspector, layout debugging

**Checklist for tester:**  
- Har screen open karo — crash nahi hona chahiye  
- Hindi/English switch karo — sab text change hona chahiye  
- Long text, short text — overflow/cut nahi hona chahiye  
- Dark theme / light theme (agar hai)  
- Landscape mode mein koi screen break na ho  
- Back button consistent kaam kare  
- Loading states dikhein (shimmer/spinner)  
- Error states dikhein (network off, empty data)  
- Cancel button completed booking mein hidden ho  
- "Completed" status teal color mein dikhe  

**How to tell tester:**  
"Har screen kholo, Hindi/English switch karo. Button placement, text overflow, color coding check karo. Cancel/Completed/Pending sab status sahi dikhne chahiye."

---

## 5. API Testing (Automated) (P1)

**What:** Automated regression testing — run full API suite before every deploy.  
**Tools:**  
- **Postman + Newman** — CLI runner for Postman collections (CI/CD integration)  
- **Jest + Supertest** — Node.js test framework (already set up)  
- **Insomnia** — alternative to Postman  
- **REST Client** (VS Code extension) — .http files for quick API testing

**How to tell tester:**  
"Postman collection banao sabhi endpoints ki. Newman se CLI mein run karo. GitHub Actions mein add karo taki har push pe automatically test ho."

---

## 6. Network / Connectivity Testing (P1)

**What:** App works on slow networks, handles disconnection gracefully.  
**Tools:**  
- **Android Emulator Network Settings** — simulate 2G, 3G, edge connections  
- **Chrome DevTools → Network tab** — throttle to Slow 3G (web testing)  
- **Charles Proxy** — throttle, intercept, modify network requests  
- **Airplane mode toggle** — manual disconnect test

**Checklist:**  
- Slow 3G pe search karo — loading indicator dikhe, crash nahi  
- Internet band karo beech mein — error message dikhe, data loss nahi  
- Internet wapas aaye — app recover kare, retry ho  
- Socket.IO reconnection test — disconnect ho ke wapas connect ho  

**How to tell tester:**  
"Android emulator mein 2G mode on karo. Search karo, booking karo — slow hoga lekin crash nahi hona chahiye. Internet off karo beech mein — data lose nahi hona chahiye."

---

## 7. Performance Testing / Profiling (P2)

**What:** App doesn't lag, no memory leaks, smooth scrolling.  
**Tools:**  
- **Flutter DevTools** — performance overlay, memory profiler, CPU profiler  
- **Android Profiler** (Android Studio) — real-time CPU, memory, network, energy  
- **Chrome DevTools Performance tab** — for web version  
- **Lighthouse** — web performance audit (web only)

**Checklist:**  
- App memory usage stable ho (leak nahi hona chahiye)  
- Scroll smooth ho (no jank / frame drops)  
- Screen transitions smooth (no delay)  
- Long list rendering fast (trips list, notifications list)  

**How to tell tester:**  
"Flutter DevTools se memory profiler open karo. App 10 minute use karo — memory steadily increase nahi honi chahiye. Trip list scroll karo — smooth hona chahiye, 60fps."

---

## 8. Load Testing (P2 — Server-side)

**What:** Server handles many concurrent users without crashing.  
**Tools:**  
- **k6** (Grafana) — modern, scriptable load testing (recommended, free)  
- **Artillery** — Node.js based, YAML config, easy setup  
- **Apache JMeter** — enterprise-grade, GUI-based (heavy but powerful)  
- **Locust** — Python-based, distributed testing  
- **autocannon** — Node.js HTTP benchmarking

**Levels to test:**

| Level | Users | Duration | What to watch |
|-------|-------|----------|---------------|
| Smoke | 10 | 30s | Basic functionality |
| Low Load | 100 | 1 min | Normal operations |
| Medium Load | 1,000 | 2 min | Response time increase |
| High Load | 5,000 | 2 min | Error rate, P95 latency |
| Stress | 10,000 | 3 min | Server limits |
| Spike | 50,000 | 1 min | Sudden burst handling |
| Endurance | 1,000 | 30 min | Memory leaks, connection pool exhaustion |

**Endpoints to test (with weight):**

| Endpoint | Weight | Auth? | Why |
|----------|--------|-------|-----|
| GET /trips/search | 40% | No | Most common action |
| GET /trips/locations | 20% | No | Autocomplete on every keystroke |
| GET /health | 10% | No | Monitoring/uptime checks |
| POST /auth/login | 15% | No | Login traffic |
| GET /bookings/my | 10% | Yes | Authenticated endpoint |
| POST /bookings | 5% | Yes | Write operation stress |

**Key metrics:**

| Metric | Target | Red Flag |
|--------|--------|----------|
| Response time (avg) | < 500ms | > 2s |
| P95 latency | < 1s | > 5s |
| Error rate | < 1% | > 5% |
| RPS (requests/sec) | > 100 | < 50 |
| Server CPU | < 80% | > 95% |
| Server memory | Stable | Keeps increasing |
| DB connections | < pool max | Pool exhausted |

**How to tell tester:**  
"k6 install karo. 100 users se start karo, 30 seconds. Phir 1000, 5000, 10000. Har level pe response time, error rate, aur server CPU dekho. 5% se zyada error aaye toh stop — woh breaking point hai."

**Sample k6 script structure:**
```
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 100 },   // ramp up
    { duration: '1m', target: 100 },     // hold
    { duration: '10s', target: 0 },      // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'],  // 95% under 1s
    http_req_failed: ['rate<0.05'],     // < 5% errors
  },
};

export default function () {
  const res = http.get('https://luharide.cloud/api/v1/trips/search?from=Dehradun&to=Purola');
  check(res, { 'status 200': (r) => r.status === 200 });
}
```

---

## 9. Device Compatibility Testing (P2)

**What:** App works on different phones, Android versions, screen sizes.  
**Tools:**  
- **BrowserStack App Live** — real devices in cloud (paid)  
- **Firebase Test Lab** — automated testing on real devices (free tier available)  
- **Real devices** — borrow phones from friends/family

**Priority devices for India:**
1. Samsung Galaxy (M/A series) — most popular in India
2. Xiaomi/Redmi — second most popular
3. Realme — third  
4. Old Android (Android 8-9) — still common in rural areas
5. Low RAM (2-3 GB) — common budget phones

**How to tell tester:**  
"Samsung M series, Redmi Note, aur ek purana Android 9 phone pe test karo. App install ho, sab screen khulein, crash nahi aaye."

---

## 10. Localization / Language Testing (P2)

**What:** Hindi and English text correct, no missing translations, no overflow.  
**Tools:**  
- **Manual testing** — switch language in app, check every screen  
- **Flutter `flutter test`** — localization key validation

**Checklist:**  
- Switch language (Settings → Language) — all UI text must change  
- No "key_not_found" or raw English text visible in Hindi mode  
- Hindi text may be longer — verify no button/card overflow  
- Cancel policy text — bilingual correct (no time numbers shown)  
- Rating info text — bilingual correct  
- Error messages — bilingual  
- **Notification text** — switch to Hindi, open Notifications screen:
  - Booking rejected → Hindi title & body shown
  - Booking auto-cancelled → Hindi title & body shown
  - Trip started → Hindi title & body shown
  - Rate ride → Hindi title & body shown
  - Verification approved/rejected → Hindi title & body shown
  - Unknown notification types → fall back to backend English text (acceptable)
- No Hinglish anywhere in UI — only proper English or proper Hindi
- FCM push notifications (system tray) may remain Hinglish — this is acceptable  

---

## 11. Regression Testing (Ongoing — Every Release)

**What:** New changes didn't break existing features.  
**Tools:**  
- **Jest** — `npm test` (208 automated tests already)  
- **Postman Collection** — full API regression suite  
- **Flutter test** — `flutter test` for widget/unit tests  

**How to tell tester:**  
"Har release se pehle pura Postman collection run karo + npm test. Agar koi test fail ho, deploy mat karo."

---

## Testing Priority Order (Summary)

| Order | Type | When | Who |
|-------|------|------|-----|
| 1 | Functional + Integration | Before every release | Tester / Automated |
| 2 | Security | Before every release | Tester |
| 3 | UI/UX | Before every release | Tester (on device) |
| 4 | API Regression | Every push (CI/CD) | Automated (Jest/Newman) |
| 5 | Network / Connectivity | Before release | Tester (emulator) |
| 6 | Load / Stress | Before launch + monthly | Tester (k6/Artillery) |
| 7 | Performance Profiling | Before launch | Tester (DevTools) |
| 8 | Device Compatibility | Before launch | Tester (real devices) |
| 9 | Localization | After any text change | Tester |
| 10 | Regression | Every release | Automated + Manual |

---

## Tools Summary

| Tool | Free? | Type | Best For |
|------|-------|------|----------|
| **Postman** | Yes (basic) | API Testing | Manual API testing, collections |
| **Newman** | Yes | API Automation | CI/CD Postman runner |
| **Jest + Supertest** | Yes | Unit/Integration | Backend automated tests |
| **k6** | Yes | Load Testing | Modern, scriptable load tests |
| **Artillery** | Yes | Load Testing | Easy YAML-based load tests |
| **JMeter** | Yes | Load Testing | Heavy enterprise testing |
| **OWASP ZAP** | Yes | Security | Automated vulnerability scan |
| **Burp Suite Community** | Yes | Security | Request interception |
| **Flutter DevTools** | Yes | Performance | Memory, CPU, widget profiling |
| **Android Profiler** | Yes | Performance | Real-time device profiling |
| **Charles Proxy** | Paid | Network | Request throttling/inspection |
| **BrowserStack** | Paid | Device | Cloud real-device testing |
| **Firebase Test Lab** | Free tier | Device | Automated multi-device testing |
| **Lighthouse** | Yes | Web Performance | Web app audit scores |
