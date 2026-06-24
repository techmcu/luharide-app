# LuhaRide — Complete Testing SOP (Standard Operating Procedure)

**Last Updated:** 2026-06-13  
**Version:** 7.0 — Complete A-to-Z (486 test cases, 221 P0, 22 parts)

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
| A-016 | Send OTP | POST /auth/send-otp with valid phone | 200, OTP sent | P0 |
| A-017 | Verify OTP (login/register) | POST /auth/verify-otp with correct OTP | 200, tokens returned | P0 |
| A-018 | Verify OTP wrong code | POST /auth/verify-otp with wrong OTP | 400 | P0 |
| A-019 | Google Sign-In valid | POST /simple-auth/google with valid Google token | 200, user created/logged in | P0 |
| A-020 | Google Sign-In invalid token | POST /simple-auth/google with garbage token | 401 | P0 |
| A-021 | Firebase Email Sign-In | POST /simple-auth/firebase-email with valid Firebase token | 200 | P1 |
| A-022 | Expired JWT access | GET /auth/me with expired access token | 401 | P0 |
| A-023 | Refresh with invalid token | POST /auth/refresh with garbage | 401 | P1 |
| A-024 | Refresh with expired refresh token | POST /auth/refresh with expired token | 401 | P1 |

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
| B-008 | Fare below minimum | Create trip with fare_per_seat = 5 | 400, min Rs.10 | P1 |
| B-009 | Fare above maximum | Create trip with fare_per_seat = 15000 | 400, max Rs.10,000 | P1 |
| B-010 | From location too short | Create trip with from_location = "A" | 400, min 2 chars | P1 |
| B-011 | Rating comment over 20 words | Submit rating with 25-word comment | 400 | P1 |
| B-012 | Cancel reason auto-prefix stripped | Cancel with reason="auto-exploit" | reason stored as "exploit" (auto- removed) | P1 |
| B-013 | Admin broadcast title too long | POST broadcast with title > 50 chars | 400, "Title max 50 characters" | P2 |
| B-014 | Admin cancel reason too long | Admin cancel trip with reason > 500 chars | 400 | P2 |

## Part C: Security & Rate Limiting Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| C-001 | Brute force lock | 10 wrong passwords for same user | 429, account locked | P0 |
| C-002 | Login during lock | Correct password while locked | 429, still blocked | P0 |
| C-003 | Other user during lock | Different user login | 200 (not affected) | P1 |
| C-004 | IP rate limit | 30 failed logins from same IP | Rate limited | P1 |
| C-005 | Forgot password rate limit | Rapid forgot-password requests | Rate limited | P2 |
| C-006 | OTP send rate limit per phone | Send OTP 4+ times to same phone in 1 hour | 429, "Too many OTP requests for this number" | P0 |
| C-007 | OTP verify rate limit | 9+ wrong OTP attempts in 15 min | 429 | P0 |
| C-008 | Search rate limit | 60+ search requests in 1 minute | 429 | P1 |
| C-009 | Upload rate limit | 30+ uploads in 1 hour | 429 | P1 |
| C-010 | Write operation rate limit | 20+ write requests in 1 minute | 429 | P1 |
| C-011 | Cancel spam protection | 5+ cancel requests in 10 seconds | 429 | P1 |
| C-012 | Google Sign-In rate limit | 10+ failed Google sign-in in 5 min | 429 | P1 |
| C-013 | Profile update rate limit | 10+ profile updates in 1 hour | 429 | P2 |
| C-014 | Bulk write rate limit | 10+ bulk schedule creates in 1 min | 429 | P2 |
| C-015 | Admin dashboard rate limit | 60+ admin requests in 15 min | 429 | P2 |

## Part D: RBAC / Cross-Role Access Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| D-001 | Passenger creates trip | POST /trips as passenger | 403 | P0 |
| D-002 | Passenger admin dashboard | GET /platform-admin/dashboard as passenger | 403 | P0 |
| D-003 | Driver admin users | GET /platform-admin/users as driver | 403 | P0 |
| D-004 | Passenger union dashboard | GET /unions/dashboard as passenger | 403 | P1 |
| D-005 | Driver union routes | GET /unions/routes as driver | 403 | P1 |
| D-006 | Union admin complaints | GET /platform-admin/complaints as union_admin | 403 | P1 |
| D-007 | Driver accesses passenger bookings | GET /bookings/my as driver (no bookings) | 200, empty (no cross-role data leak) | P1 |
| D-008 | Passenger starts trip | PUT /trips/:id/start as passenger | 403 | P1 |
| D-009 | Passenger completes trip | PUT /trips/:id/complete as passenger | 403/404 | P1 |
| D-010 | Non-owner driver cancels trip | PUT /trips/:id/cancel as different driver | 404 (trip not found for this driver) | P1 |
| D-011 | Passenger responds to booking | PUT /bookings/:id/respond as passenger | 403/404 | P1 |
| D-012 | Non-admin grants KYC reverify | POST /admin/kyc/drivers/:id/reverify as driver | 403 | P1 |

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
| E-013 | Delete FCM token | DELETE /notifications/fcm-token | 200 | P2 |
| E-014 | Mark single notification read | POST /notifications/:id/read | 200 | P2 |
| E-015 | Search routes | GET /routes/search?from=Dehradun&to=Purola | 200 | P1 |
| E-016 | Popular routes | GET /routes/popular | 200 | P2 |
| E-017 | View user rating summary | GET /reviews/user/:userId/summary | 200, avg rating + count | P1 |
| E-018 | View user review bundle | GET /reviews/user/:userId/bundle | 200, reviews + summary | P2 |

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
| F-031 | Create trip — min 30 min advance | Create trip with departure 10 min from now | 400, "30 min advance required" | P0 |
| F-032 | Create trip — overlapping trip blocked | Create 2nd trip overlapping with existing scheduled trip | 400, "existing trip overlaps" | P0 |
| F-033 | Create trip — blocked driver | Create trip while cancel_blocked_until > NOW | 400, vague message | P0 |
| F-034 | Delete trip — after 1 hour window | Delete trip created > 1 hour ago | 400, "Use cancel instead" | P1 |
| F-035 | Book — 10 min cooldown after cancel | Cancel booking on trip A → re-book trip A within 10 min | 400, "wait X minutes" | P0 |
| F-036 | Book — cooldown cross-trip allowed | Cancel booking on trip A → book trip B immediately | 201, allowed (cooldown is per-trip) | P1 |
| F-037 | Book — passenger phone required | Book independent driver ride without phone in profile | 400, "phone required" | P0 |
| F-038 | Book — idempotency key prevents duplicate | POST /bookings twice with same idempotency_key, same data | 1st: 201, 2nd: 200 (returns existing) | P1 |
| F-039 | Book — idempotency key conflict | POST /bookings with same key but different trip/seats | 409, "key already used" | P1 |
| F-040 | Accept — seat conflict auto-rejects | 2 passengers book same seats (pending), driver accepts 1st | 2nd booking auto-cancelled, seats conflict | P0 |
| F-041 | Accept — other pending same seat auto-cancelled | Accept booking → other pending bookings on same seats | Auto-cancelled with notification "seats given to another" | P1 |
| F-042 | Auto-start at departure time | Create trip 30 min ahead, wait for departure → cron runs | Trip: scheduled → in_progress, driver notified | P0 |
| F-043 | Auto-start cancels pending bookings | Pending bookings exist at auto-start | Pending → cancelled, reason="auto-expired-trip-started", passenger notified | P0 |
| F-044 | Auto-complete at arrival time | Trip in_progress, arrival_time (departure + 2h) passes → cron | Trip: in_progress → completed, confirmed bookings → completed | P0 |
| F-045 | Auto-complete leftover pending | Rare: pending booking exists at auto-complete time | Pending → cancelled, reason="auto-expired-trip-completed" | P1 |
| F-046 | Seat math — book reduces available | Create 7-seat vehicle trip → book 2 seats | available_seats = 4 (7 - 1 driver - 2 booked) | P0 |
| F-047 | Seat math — cancel restores available | Cancel 2-seat booking from above | available_seats = 6 (restored) | P0 |
| F-048 | Full trip hidden from search | Book all available seats → search | Trip not in search results (available_seats = 0) | P0 |
| F-049 | Cancel restores → trip visible again | Cancel one booking on full trip → search | Trip appears again in results | P1 |
| F-050 | Seat 1 always blocked | Any attempt to book seat 1 | 400, "Seat 1 is driver seat" | P0 |
| F-051 | available_seats cannot exceed total_capacity | DB constraint: available_seats <= total_capacity | CHECK constraint prevents overflow | P1 |
| F-052 | Stale pending cleanup (nightly job) | Pending booking older than threshold, not responded | Auto-cancelled by rideCleanupJob, passenger notified | P1 |
| F-053 | Create trip — estimated duration valid | POST /trips with estimated_duration_hours=3 | 201, arrival_time = departure + 3h | P0 |
| F-054 | Create trip — estimated duration omitted | POST /trips without estimated_duration_hours field | 201, arrival_time = departure + 2h (default) | P0 |
| F-055 | Create trip — estimated duration below min | POST /trips with estimated_duration_hours=0.5 | 400, "must be between 1 and 12 hours" | P0 |
| F-056 | Create trip — estimated duration above max | POST /trips with estimated_duration_hours=15 | 400, "must be between 1 and 12 hours" | P0 |
| F-057 | Create trip — estimated duration NaN | POST /trips with estimated_duration_hours="abc" | 400, "must be between 1 and 12 hours" | P1 |
| F-058 | Create trip — estimated duration boundary 1h | POST /trips with estimated_duration_hours=1 | 201, arrival_time = departure + 1h | P1 |
| F-059 | Create trip — estimated duration boundary 12h | POST /trips with estimated_duration_hours=12 | 201, arrival_time = departure + 12h | P1 |
| F-060 | Daily ride creation limit (4/day) | Create 4 trips in same day → create 5th | 400, "maximum of 4 rides per day" | P0 |
| F-061 | Daily ride limit resets next day | Hit limit today → next day create trip | 201, allowed (new day) | P1 |
| F-062 | Daily ride limit counts only independent driver | Union trips do NOT count toward 4/day limit | Independent limit independent; union rides unaffected | P1 |

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
| G-033 | Pending cancel — NO penalty | Cancel pending (not confirmed) booking | No cancel count increment, no auto-rating, no block risk | P0 |
| G-034 | Pending cancel — no auto-rating | Cancel pending booking → check ride_ratings | No auto-1-star inserted | P1 |
| G-035 | Confirmed cancel — auto-rating + rate prompt | Cancel confirmed booking | Auto-1-star inserted + driver gets rate notification | P0 |

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

### G4: Create+Cancel Abuse Tracking

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| G-060 | Create+cancel daily limit warning | Driver cancels 5 rides in one day (below monthly strike limit) | Warning notification: "Too many cancellations", driver_abuse_flags row with flag_type='create_cancel_abuse' | P0 |
| G-061 | Create+cancel monthly strike accumulation | Trigger daily limit 3 times in same month | 3 strikes → 48h block, notification "Account temporarily restricted for 48 hours" | P0 |
| G-062 | Create+cancel block sets cancel_blocked_until | 3 monthly strikes → check users table | cancel_blocked_until = NOW + 48h | P0 |
| G-063 | Create+cancel only counts driver-initiated cancels | Admin cancels driver's trip → check abuse count | NOT counted (cancelled_by='admin' excluded) | P1 |
| G-064 | Create+cancel flag visible in admin user detail | Admin GET /platform-admin/users/:id for flagged driver | abuse_flags array shows create_cancel_abuse entries with reason, month, violation_count | P1 |

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

### H3: Low Rating Auto-Complaint

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| H-030 | Rating ≤ 2 with comment = auto-complaint | Submit 2-star rating with comment "bad driver" | driver_abuse_flags row: flag_type='low_rating_report', reason includes rating + comment + booking_id | P0 |
| H-031 | Rating ≤ 2 without comment = NO complaint | Submit 1-star rating without comment | No low_rating_report row inserted | P0 |
| H-032 | Rating 3+ with comment = NO complaint | Submit 3-star rating with comment "okay driver" | No low_rating_report row inserted | P1 |
| H-033 | Auto-complaint visible in admin | Admin GET /platform-admin/flagged-drivers | low_rating_report entries visible with driver name/phone/avg rating | P1 |

### H4: Rating Threshold System

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| H-040 | Threshold skipped below 5 ratings | Driver has 4 ratings, avg 1.0 | No threshold action (min 5 ratings required) | P0 |
| H-041 | Warning at avg < 2.0 (5+ ratings) | Driver receives 5th rating, avg = 1.8 | driver_abuse_flags: 'low_avg_rating_warning', notification "Your ratings are low" | P0 |
| H-042 | Warning not duplicated same month | Same driver gets another low rating same month, avg still < 2.0 | No second warning flag (already warned this month) | P1 |
| H-043 | Block at avg < 1.5 (5+ ratings) | Driver receives rating dropping avg to 1.4 | 7-day block: cancel_blocked_until set, flag 'low_avg_rating_block', notification "Account restricted — low ratings" | P0 |
| H-044 | Blocked driver cannot create trip | Driver blocked by rating threshold → POST /trips | 400, blocked (cancel_blocked_until > NOW) | P0 |
| H-045 | Rating avg ≥ 2.0 = no action | Driver has 6 ratings, avg = 2.5 | No warning, no block | P1 |

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
| J-017 | Register union | POST /union/register with name, documents | 201 | P0 |
| J-018 | Register duplicate union | POST /union/register again | 400/409 | P1 |
| J-019 | Update union documents | PATCH /union/me/documents | 200 | P1 |
| J-020 | Remove driver from union | DELETE /union/drivers/:driverId | 200 | P1 |
| J-021 | Create trip for union driver | POST /union/trips | 201 | P1 |
| J-022 | Get union trips | GET /union/trips | 200 | P1 |
| J-023 | Schedule poster PDF | GET /union/schedules/:id/poster | 200, PDF response | P2 |
| J-024 | Combined poster PDF | GET /union/schedules/poster-combined | 200, PDF response | P2 |
| J-025 | Admin approve union | POST /union/admin/unions/:id/approve | 200 | P0 |
| J-026 | Admin reject union | POST /union/admin/unions/:id/reject | 200 | P0 |
| J-027 | Independent drivers directory | GET /admin/directory/independent-drivers | 200 | P2 |

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
| K-019 | Broadcast history | GET /platform-admin/notifications/history | 200, list of past broadcasts | P1 |
| K-020 | Broadcast dedup blocked | Send same title+body broadcast twice within 1 hour | 400, "duplicate notification" | P1 |
| K-021 | App config GET | GET /platform-admin/config | 200 | P2 |
| K-022 | App config PATCH | PATCH /platform-admin/config with valid data | 200 | P2 |
| K-023 | DB health endpoint | GET /platform-admin/db-health | 200, table sizes + dead tuples | P1 |
| K-024 | Admin cancel sets cancelled_by=admin | Admin cancel trip → check trips.cancelled_by | 'admin' | P0 |
| K-025 | Admin cancel notifies passengers | Admin cancel trip with bookings → check notifications | Passengers get "Ride cancelled by admin" | P0 |
| K-026 | Admin cancel notifies driver | Admin cancel trip → check driver notification | Driver gets "Your ride was cancelled by admin" | P0 |
| K-027 | Admin cancel cleans rate reminders | Admin cancel trip → check pending_rate_notifications | Deleted for affected bookings | P1 |
| K-028 | Union FCM per-union toggle | PATCH /platform-admin/union-fcm/:unionId | 200 | P2 |
| K-029 | Get flagged drivers | GET /platform-admin/flagged-drivers | 200, list of unresolved flags with driver_name, avg_rating, flag_type | P0 |
| K-030 | Resolve flagged driver | PATCH /platform-admin/flagged-drivers/:id/resolve | 200, resolved_at set, resolved_by = admin_id | P0 |
| K-031 | Resolve already-resolved flag | PATCH /platform-admin/flagged-drivers/:id/resolve on resolved flag | 404, "already resolved" | P1 |
| K-032 | Delete fake/spam rating | DELETE /platform-admin/ratings/:id | 200, rating deleted from ride_ratings | P0 |
| K-033 | Delete non-existent rating | DELETE /platform-admin/ratings/999 | 404, "Rating not found" | P1 |
| K-034 | Ban driver permanently | POST /platform-admin/users/:id/ban with reason, no duration_days | 200, cancel_blocked_until = 2099-12-31, notification sent | P0 |
| K-035 | Ban driver temporarily | POST /platform-admin/users/:id/ban with reason + duration_days=7 | 200, cancel_blocked_until = NOW + 7d, notification sent | P0 |
| K-036 | Ban without reason | POST /platform-admin/users/:id/ban without reason | 400, "Reason is required" | P0 |
| K-037 | Ban with short reason | POST /platform-admin/users/:id/ban with reason="ab" | 400, "min 3 characters" | P1 |
| K-038 | Unban driver | POST /platform-admin/users/:id/unban | 200, cancel_blocked_until = NULL, all unresolved flags resolved, notification sent | P0 |
| K-039 | Unban clears all flags | Unban driver → check driver_abuse_flags | All flags for user resolved (resolved_at set, resolved_by = admin) | P1 |
| K-040 | User detail shows ratings + flags | GET /platform-admin/users/:id for driver with ratings | Response includes ratings (total, avg, low_ratings), recent_reviews, abuse_flags arrays | P0 |
| K-041 | Non-admin cannot access flagged-drivers | GET /platform-admin/flagged-drivers with driver token | 403 | P0 |
| K-042 | Non-admin cannot ban/unban | POST /platform-admin/users/:id/ban with passenger token | 403 | P0 |

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
| L-011 | Trip completed notification localized | Trip auto-completes → check notification in Hindi mode | Title: "शुभ यात्रा!", Body: "उम्मीद है आपकी यात्रा LuhaRide के साथ अच्छी रही!" | P1 |

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
| M-010 | Microservice health checks | GET /health on each port (3001-3004) | All return ok + service name | P1 |
| M-011 | Gateway proxies correctly | GET /api/v1/trips/search via gateway :3000 | Proxied to core service, 200 | P0 |
| M-012 | PM2 process restart | pm2 restart all → check uptime | All processes running, no crash loops | P1 |
| M-013 | Migration runs cleanly | npm run migrate on fresh DB | All 061 migrations succeed in order | P0 |
| M-014 | VACUUM ANALYZE in nightly job | Check cleanup job logs after midnight IST | "VACUUM ANALYZE complete" logged | P2 |
| M-015 | Nightly Redis health logged | Check cleanup job logs | Redis memory + key count logged | P2 |

## Part N: Driver Verification & KYC Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| N-001 | Submit driver verification | POST /driver-verification with documents | 200, status=pending | P0 |
| N-002 | Get verification status | GET /driver-verification | 200, current status | P0 |
| N-003 | Submit without documents | POST /driver-verification with no files | 400 | P1 |
| N-004 | Admin approve driver | POST /admin/driver-requests/:id/approve | 200, status=approved | P0 |
| N-005 | Admin reject driver | POST /admin/driver-requests/:id/reject with reason | 200, status=rejected | P0 |
| N-006 | Approved driver can create trip | After approval → POST /trips | 201 | P0 |
| N-007 | Rejected driver cannot create trip | After rejection → POST /trips | 403 | P0 |
| N-008 | View submitted KYC documents | GET /kyc/submitted-documents | 200, document list | P1 |
| N-009 | Stream KYC document file | GET /kyc/document-file?path=... | 200, file stream | P2 |
| N-010 | Admin grant driver reverify | POST /admin/kyc/drivers/:userId/reverify | 200, status=needs_reverify | P0 |
| N-011 | Reverify same user twice in one day | POST /admin/kyc/drivers/:userId/reverify twice same day | 400, "already granted today" | P1 |
| N-012 | Reverified driver uploads new docs | After reverify → re-submit verification | 200, status=pending | P1 |
| N-013 | Admin grant union reverify | POST /admin/kyc/unions/:unionId/reverify | 200 | P1 |
| N-014 | Union reverify same day blocked | POST /admin/kyc/unions/:id/reverify twice same day | 400 | P1 |
| N-015 | List pending union doc requests | GET /admin/union-doc-requests?status=pending | 200, list | P1 |
| N-016 | Approve union doc request | POST /admin/union-doc-requests/:id/approve | 200, documents_status=approved | P1 |
| N-017 | Reject union doc request | POST /admin/union-doc-requests/:id/reject | 200, documents_status=needs_reverify | P1 |
| N-018 | Reverify notification sent | Admin reverify → check user notifications | type=kyc_reverify_required, deadline in data | P1 |
| N-019 | Approval notification sent | Admin approve docs → check union admin notifications | type=union_documents_approved | P1 |

## Part O: File Upload Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| O-001 | Upload driver document | POST /uploads/driver-doc with image file | 200, file path returned | P0 |
| O-002 | Upload union document | POST /uploads/union-doc with image file | 200, file path returned | P1 |
| O-003 | Upload without auth | POST /uploads/driver-doc without JWT | 401 | P0 |
| O-004 | Upload rate limited | 30+ uploads in 1 hour | 429 | P1 |
| O-005 | Upload oversized file | Upload file > max size | 400 | P1 |

## Part P: Cron Jobs & Background Tasks

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| P-001 | Trip lifecycle job runs | Check logs for "[TripLifecycle]" every 2 min | Auto-start and auto-complete entries when applicable | P0 |
| P-002 | Rate notification job runs | Check logs for "Rate notification job" every 15 min | Pending notifications sent when send_after <= NOW | P0 |
| P-003 | Nightly cleanup runs | Check logs at midnight IST (18:30 UTC) | "[Cleanup] evening maintenance complete" logged | P0 |
| P-004 | Stale pending bookings cleaned | Old pending booking not responded → nightly job | Booking cancelled, passenger notified "driver did not respond" | P1 |
| P-005 | Old notifications deleted | Read notification > 48h, unread > 168h | Deleted by cleanup job | P1 |
| P-006 | Expired FCM tokens deleted | FCM token older than retention period | Deleted by cleanup job | P2 |
| P-007 | Old trips deleted (retention) | Completed/cancelled trip older than retention | Trip + bookings deleted, ratings kept (booking_id SET NULL) | P2 |
| P-008 | Advisory lock prevents duplicate jobs | 2 instances running same job | Only 1 gets the lock, other skips | P1 |
| P-009 | Graceful shutdown — monolith | Send SIGTERM to monolith process | Jobs stopped → HTTP server closes → DB pools drained → clean exit(0), logged | P0 |
| P-010 | Graceful shutdown — microservices | Send SIGTERM to each microservice (auth/core/union/platform) | Each exits cleanly: server closes → DB pools drained → exit(0) | P0 |
| P-011 | Graceful shutdown — gateway | Send SIGTERM to gateway process | Gateway exits cleanly: server closes → DB pools drained → exit(0) | P0 |
| P-012 | Force shutdown after 15s timeout | SIGTERM + simulate stuck connections (server.close hangs) | Force exit(1) after 15s, logged as forced | P1 |
| P-013 | Double SIGTERM ignored | Send SIGTERM twice rapidly | Second signal ignored (shuttingDown guard), no double-exit | P1 |
| P-014 | SIGINT handled same as SIGTERM | Send SIGINT (Ctrl+C) to monolith | Same clean shutdown as SIGTERM | P1 |
| P-015 | Job timers cleaned on shutdown | SIGTERM during running jobs | All cron tasks stopped, setInterval timers cleared, no orphan timers | P0 |
| P-016 | Staggered job start guarded | SIGTERM within 5s of startup (before all jobs started) | Pending setTimeout callbacks skip job.start() (shuttingDown check) | P1 |

## Part Q: Notification Flow & Timing Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| Q-001 | Booking request notification (approval ON) | Passenger books seats on require_approval=true trip | Driver gets "New booking request!" instantly | P0 |
| Q-002 | Booking confirmed notification | Driver accepts pending booking | Passenger gets "Booking confirmed!" instantly | P0 |
| Q-003 | Booking rejected notification | Driver rejects pending booking | Passenger gets "Booking not approved" instantly | P0 |
| Q-004 | Booking cancelled notification | Passenger cancels confirmed booking | Driver gets "Booking cancelled" instantly | P0 |
| Q-005 | Auto-approved booking (approval OFF) | Passenger books on require_approval=false trip | Booking status=confirmed instantly, driver notified | P0 |
| Q-006 | Ride started notification (auto-start) | Departure time arrives → cron runs | Driver gets "Your ride has started!" (0-2 min delay) | P0 |
| Q-007 | Pending auto-cancel at start | Pending bookings exist when trip auto-starts | Pending passengers get "Driver did not respond" notification | P0 |
| Q-008 | Happy Journey notification (auto-complete) | Departure + 2h → cron runs | Each confirmed passenger gets "Happy Journey!" (NOT "Rate your experience") | P0 |
| Q-009 | Rate reminder timing | arrival_time + 2h → rateNotificationJob runs | Driver + passengers get "Rate your ride" notification | P0 |
| Q-010 | Rate reminder NOT sent if cancelled | Trip cancelled before 5h mark | No rate notification sent, pending_rate_notifications deleted | P0 |
| Q-011 | Rate reminder checks completed status | Booking status=completed at 5h mark | Rate notification sent (not just confirmed) | P0 |
| Q-012 | Driver cancel → passengers notified | Driver cancels trip with bookings | ALL passengers (confirmed+pending) get "Ride cancelled" | P0 |
| Q-013 | Driver cancel → auto 1-star silent | Driver cancels with confirmed bookings | Auto-1-star inserted per confirmed booking, NO notification for it | P1 |
| Q-014 | Passenger cancel → driver notified | Passenger cancels confirmed booking | Driver gets "Booking cancelled" notification | P0 |
| Q-015 | Passenger cancel → auto 1-star silent | Passenger cancels confirmed booking | Auto-1-star on passenger, NO notification for it | P1 |
| Q-016 | Admin cancel → driver notified | Admin cancels trip | Driver gets "Your ride was cancelled by admin" | P0 |
| Q-017 | Admin cancel → passengers notified | Admin cancels trip with bookings | All passengers get "Ride cancelled by admin" | P0 |
| Q-018 | Admin cancel → rate reminders deleted | Admin cancels trip | pending_rate_notifications deleted for all affected bookings | P1 |
| Q-019 | Pending cancel → NO notification to driver | Passenger cancels pending (not confirmed) booking | No cancel notification to driver (not confirmed yet) | P1 |
| Q-020 | KYC approved notification | Admin approves driver verification | Driver gets "Verification approved" | P1 |
| Q-021 | KYC rejected notification | Admin rejects driver verification | Driver gets "Verification rejected" with reason | P1 |
| Q-022 | KYC reverify notification | Admin grants reverify | Driver gets "Please re-submit your documents" | P1 |
| Q-023 | Union docs approved notification | Admin approves union documents | Union admin gets "Union documents approved" | P1 |
| Q-024 | No duplicate notifications | Same event triggered twice (idempotency) | Only 1 notification sent, not 2 | P1 |
| Q-025 | Happy Journey has NO rating mention | Check auto-complete notification text | Body must NOT contain "rate" or "review" or "experience" | P0 |
| Q-026 | Rate notification uses arrival_time + 2h | Create trip with estimated_duration_hours=4 → complete → check pending_rate_notifications | send_after = departure + 4h (arrival) + 2h = departure + 6h | P0 |
| Q-027 | Rate notification dedup (UNIQUE constraint) | Same booking triggers rate notification insert twice | ON CONFLICT (booking_id) DO NOTHING — only 1 row exists | P0 |
| Q-028 | Create+cancel abuse warning notification | Driver cancels 5 rides in one day | Notification type='account_warning', title="Warning: Too many cancellations" | P0 |
| Q-029 | Create+cancel abuse block notification | 3 monthly strikes triggered | Notification type='account_warning', title="Account temporarily restricted", body mentions 48 hours | P0 |
| Q-030 | Rating threshold warning notification | Driver avg drops below 2.0 (5+ ratings) | Notification type='account_warning', title="Warning: Your ratings are low" | P1 |
| Q-031 | Rating threshold block notification | Driver avg drops below 1.5 (5+ ratings) | Notification type='account_warning', title="Account restricted — low ratings" | P1 |
| Q-032 | Admin ban notification | Admin bans driver permanently | Notification type='account_warning', title="Account restricted by admin", body="permanently restricted" | P1 |
| Q-033 | Admin ban temporary notification | Admin bans driver for 7 days | Notification body="restricted for 7 days" | P1 |
| Q-034 | Admin unban notification | Admin unbans driver | Notification type='account_warning', title="Account restriction lifted" | P1 |

## Part R: Socket.IO / Real-Time Tracking Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| R-001 | Socket connect with valid JWT | Connect with valid token in handshake.auth.token | Connected, auto-joined user:{userId} room | P0 |
| R-002 | Socket connect without token | Connect without auth token | Connected as anonymous (authFailed=true), no user room | P0 |
| R-003 | Socket connect with invalid token | Connect with garbage JWT | Connected as anonymous (authFailed=true) | P1 |
| R-004 | Join trip room | Emit 'join-trip' with tripId (authenticated) | Joined room trip:{tripId}, ack received | P0 |
| R-005 | Leave trip room | Emit 'leave-trip' with tripId | Left room trip:{tripId} | P1 |
| R-006 | Driver location update | Driver emits 'location-update' with lat/lng/tripId | Location broadcast to trip room subscribers | P0 |
| R-007 | Location update — invalid coordinates | Emit location-update with lat=999, lng=999 | Silently dropped (no broadcast) | P1 |
| R-008 | Location update — throttle (200ms) | Emit 5 location updates within 100ms | Only ~1 processed, rest throttled | P1 |
| R-009 | Socket rate limit (20 conn/min/IP) | Open 21 connections from same IP within 60s | 21st connection rejected: "Too many connections" | P0 |
| R-010 | Socket disconnect cleanup | Disconnect authenticated socket | User removed from rooms, no orphan listeners | P1 |
| R-011 | Real-time notification delivery | Create booking → check driver's socket | Notification emitted to user:{driverId} room instantly | P0 |
| R-012 | Socket reconnection after disconnect | Disconnect then reconnect with same token | Re-authenticated, re-joined user room | P1 |

## Part S: Account Lockout & Multi-Auth Tests

### S1: Account Lockout

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| S-001 | Failed login increments counter | POST /simple-auth/login with wrong password | failed_login_attempts incremented | P0 |
| S-002 | Account locked after 10 failures | 10 wrong passwords for same user | 429, "Account temporarily locked. Try again in 30 minute(s)." | P0 |
| S-003 | Login blocked during lockout | Correct password while locked_until > NOW | 429, still blocked with remaining minutes | P0 |
| S-004 | Lockout expires after 30 min | Wait 30 min (or advance DB time) → login with correct password | 200, login succeeds | P1 |
| S-005 | Successful login resets counter | Login correctly after partial failures (e.g., 5 wrong) | failed_login_attempts = 0, locked_until = NULL | P0 |
| S-006 | OTP verify resets lockout | Verify OTP for locked user | failed_login_attempts = 0, locked_until = NULL | P1 |
| S-007 | Other users unaffected during lockout | Lock user A → login as user B | 200, user B login works | P1 |

### S2: Multi-Auth Methods

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| S-010 | Email/password signup | POST /simple-auth/signup with email/password/name | 201, user created | P0 |
| S-011 | Duplicate email signup | POST /simple-auth/signup with existing email | 409/400, blocked | P0 |
| S-012 | Email/password login | POST /simple-auth/login with correct credentials | 200, tokens returned | P0 |
| S-013 | Password change | PUT /simple-auth/change-password with old + new password | 200, password changed | P1 |
| S-014 | Password reset via OTP | POST /simple-auth/forgot-password → receive OTP → verify | 200, password reset | P1 |
| S-015 | Google Sign-In creates new user | POST /simple-auth/google with valid Google token (new email) | 200, user created with google_id | P0 |
| S-016 | Google Sign-In existing user | POST /simple-auth/google with existing Google user | 200, login (no duplicate) | P1 |
| S-017 | Firebase email sign-in | POST /simple-auth/firebase-email with valid Firebase token | 200, user created/logged in with firebase_uid | P1 |

## Part T: Complaint & Broadcast System Tests

### T1: Complaints

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| T-001 | Submit complaint | POST /platform-admin/complaints/submit with subject + body | 201, status='open' | P0 |
| T-002 | Submit complaint — subject too long | Subject > 200 chars | 400 | P1 |
| T-003 | Submit complaint — body too long | Body > 2000 chars | 400 | P1 |
| T-004 | Submit complaint — missing subject | POST without subject field | 400 | P1 |
| T-005 | View my complaints | GET /platform-admin/complaints/mine (as user) | 200, list of own complaints | P0 |
| T-006 | Admin list complaints | GET /platform-admin/complaints (as admin) | 200, paginated list with user_name, user_role | P0 |
| T-007 | Admin filter by status | GET /platform-admin/complaints?status=open | 200, only open complaints | P1 |
| T-008 | Admin search complaints | GET /platform-admin/complaints?search=booking | 200, filtered by subject/user name | P1 |
| T-009 | Admin view complaint detail | GET /platform-admin/complaints/:id | 200, full complaint with user info | P1 |
| T-010 | Admin resolve complaint | POST /platform-admin/complaints/:id/resolve with resolution_note | 200, status='resolved', resolved_by set | P0 |
| T-011 | Resolve notification sent to user | Admin resolves complaint → check user notifications | type='complaint_resolved' notification sent | P1 |
| T-012 | Non-admin cannot list all complaints | GET /platform-admin/complaints as driver | 403 | P0 |

### T2: Broadcasts

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| T-020 | Send broadcast to all | POST /platform-admin/notifications/bulk segment='all' | 200, sentCount = total users | P0 |
| T-021 | Send broadcast to drivers | POST /platform-admin/notifications/bulk segment='drivers' | 200, sentCount = driver count | P0 |
| T-022 | Send broadcast to passengers | POST /platform-admin/notifications/bulk segment='passenger' | 200, sentCount = passenger count | P1 |
| T-023 | Broadcast dedup (same title+body within 1h) | Send same broadcast twice within 1 hour | 2nd: 400, "already sent within the last hour" | P0 |
| T-024 | Broadcast title max 50 chars | POST with title > 50 chars | 400 | P1 |
| T-025 | Broadcast body max 150 chars | POST with body > 150 chars | 400 | P1 |
| T-026 | Broadcast segment > 10,000 users | Segment with > 10,000 matching users | 400, rejected (too many) | P1 |
| T-027 | Broadcast history | GET /platform-admin/notifications/history | 200, list with admin_name, sent_count, created_at | P0 |
| T-028 | Non-admin cannot broadcast | POST /platform-admin/notifications/bulk as driver | 403 | P0 |

## Part U: Data Retention & Cleanup Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| U-001 | Read notifications cleaned (48h) | Read notification > 48h old → nightly job runs | Notification deleted | P1 |
| U-002 | Unread notifications cleaned (168h) | Unread notification > 7 days old → nightly job runs | Notification deleted | P1 |
| U-003 | Login history cleaned (90 days) | Login history > 90 days old → nightly job | Rows deleted | P2 |
| U-004 | Location history cleaned (7 days) | GPS location > 7 days old → nightly job | Rows deleted | P2 |
| U-005 | SOS logs cleaned (90 days) | SOS log > 90 days old → nightly job | Rows deleted | P2 |
| U-006 | FCM tokens cleaned (30 days) | FCM token > 30 days old → nightly job | Token deleted | P1 |
| U-007 | Resolved complaints cleaned (90 days) | Resolved complaint > 90 days post-resolution → nightly job | Complaint deleted | P2 |
| U-008 | Independent trips cleaned (7 days) | Completed/cancelled independent trip > 7 days → nightly job | Trip + bookings deleted, ratings kept (booking_id SET NULL) | P1 |
| U-009 | Union trips cleaned (15 days) | Completed/cancelled union trip > 15 days → nightly job | Trip + bookings deleted | P1 |
| U-010 | Broadcasts capped at 100 | 101st broadcast → nightly job | Oldest broadcast deleted (FIFO) | P2 |
| U-011 | Union schedules cleaned (15 days) | Past union schedule > 15 days → nightly job | Schedule deleted | P2 |
| U-012 | Union schedules capped at 100/union | 101st schedule for same union → nightly job | Oldest deleted (FIFO) | P2 |
| U-013 | Driver verification requests cleaned (90 days) | Approved/rejected request > 90 days → nightly job | Request deleted | P2 |
| U-014 | VACUUM ANALYZE runs post-cleanup | Nightly job completes → check logs | "VACUUM ANALYZE complete" for high-churn tables | P1 |
| U-015 | Pending booking auto-expiry (pre-departure) | Pending booking 1 min before departure → pendingBookingExpiryJob runs | Status=cancelled, reason='auto-expired-before-departure', seats restored, passenger notified | P0 |
| U-016 | Daily stats aggregated | 18:35 UTC → dailyStatsJob runs | daily_stats row inserted with new_users, new_trips, completed/cancelled counts | P0 |
| U-017 | Daily stats retention (180 days) | Stats row > 180 days → dailyStatsJob | Old row deleted | P2 |
| U-018 | Daily stats UPSERT | Run dailyStatsJob twice for same date | No duplicate, values overwritten | P1 |

## Part V: Union Advanced & Poster Tests

| ID | Scenario | Steps | Expected | Priority |
|----|----------|-------|----------|----------|
| V-001 | Generate single poster PDF | GET /union/schedules/:id/poster (union admin) | 200, Content-Type: application/pdf | P0 |
| V-002 | Generate combined poster PDF | GET /union/schedules/poster-combined (union admin) | 200, Content-Type: application/pdf | P1 |
| V-003 | Poster daily limit (3/day) | Generate 3 posters → generate 4th | 400, daily limit reached (Hindi message) | P0 |
| V-004 | Poster limit resets next day | Hit limit today → next day generate poster | 200, allowed | P1 |
| V-005 | Poster for other union's schedule | GET /union/schedules/:id/poster for schedule not in own union | 403/404 | P1 |
| V-006 | Non-union-admin cannot generate poster | GET /union/schedules/:id/poster as passenger | 403 | P0 |
| V-007 | Log WhatsApp contact click | POST /unions/contact-log type='whatsapp', driver_id | 200, contact_log row inserted | P1 |
| V-008 | Log phone contact click | POST /unions/contact-log type='phone', driver_id | 200, contact_log row inserted | P1 |
| V-009 | Contact stats for union admin | GET /unions/contact-stats | 200, aggregated click counts per driver | P1 |
| V-010 | Contact logs cleaned (30 days) | Contact log > 30 days → nightly job | Log deleted | P2 |
| V-011 | Bulk schedule creation | POST /unions/schedules/bulk with valid routes + times | 201, multiple schedules created | P0 |
| V-012 | Bulk schedule daily limit (3/day) | Create bulk schedules 3 times → 4th attempt | 400, daily limit | P0 |
| V-013 | Cancel union schedule (within 1h) | DELETE /unions/schedules/:id within 1 hour of creation | 200, schedule + trips cancelled | P1 |
| V-014 | Cancel union schedule (after 1h) | DELETE /unions/schedules/:id after 1 hour | 400, "Use cancel instead" | P1 |
| V-015 | API version rewrite (/api/v1 → /api) | GET /api/v1/trips/search | 200, transparently rewritten to /api/trips/search | P0 |

## Part W: Backend Automated-Test Coverage Map & Gaps

> **Why this part exists:** Parts A–V are mostly *manual/integration* scenarios. This
> part tracks which backend logic has **automated Jest tests** (run on every push by
> CI), so a tester/dev can see at a glance what is regression-protected and what still
> needs an automated test. Update this table whenever a `*.test.js` file is added.
>
> **Current state:** **519 automated tests, 53 suites, all green** (`cd backend && npm test`).
> Baseline before the geo/poster pass was 482; +28 added for poster/geo helpers, then
> +9 for driver-verification re-upload/url helpers.

### W1: Modules WITH automated coverage (regression-protected)

| Module | Test file(s) | What's locked down |
|--------|-------------|--------------------|
| Auth / signup / login | `simpleAuthController.test.js` | signup 201/409/400, login 200/401/403, lockout, password change, forgot-password |
| Booking lifecycle | `bookingController.test.js` + `.cancel` `.edge` `.respond` | book, accept/reject, cancel rules, seat math, edge inputs |
| Trip create/lifecycle | `tripController.test.js` `.lifecycle` `.createTrip.date` `.cancel` | create, auto start/complete, cancel, date handling |
| Trip search | `tripController.search.test.js` + `tripSearchColumns.test.js` | search filters, explicit column selection |
| **Trip search geo helpers** | `tripSearchController.geo.test.js` *(new)* | `geoBoundingBox` math (lat/lng span, cos correction, pole clamp), `requireUuid` guard |
| KYC admin / documents | `kycAdminController*.test.js`, `kycDocuments*.test.js` | approve/reject, reverify-once-per-day, doc collect/stream |
| Notifications | `notificationController.test.js` | list, mark read, localization keys |
| Admin directory | `adminDirectoryController.test.js` | listing/search |
| **Union poster helpers** | `unionHelpers.test.js` *(new)* | `cleanUnionName`, `cleanPosterHeader`, `cleanPosterCustomText` (120-char cap), `getPosterTheme`/`Colors` fallback, `ensurePlatformAdmin` guard |
| API version rewrite | `apiVersionRewrite.test.js` | `/api/v1/*` → `/api/*` |
| Ratings / reviews | `reviewService.test.js` | submit 1–5, comment cap, ownership (passenger↔driver), cancel-eligibility rules, duplicate guard, summary avg |
| Fare ceiling (anti-overcharge) | `fareService.test.js` | `estimateFare` fair+max, min-fare floor, `validateFare` blocks above ceiling & reveals only max |
| **Driver-verification gate helpers** | `driverVerificationController.reupload.test.js` *(new)* | `isDriverAllowedToReupload` (flag===true, deadline window, NaN-deadline = open-ended), `orderedSanitizedDocUrls` (order-preserve, drop blanks/invalid) |
| Services layer | colocated `*.test.js` | all services have a test file |

### W2: Modules WITHOUT a dedicated automated test (gaps) — with backend test logic

> Priority = how important an automated test is. Many are partially exercised via
> integration scripts (`scripts/testing/full-test-v2.js`) but lack fast unit coverage.

| Pri | Module | Why it matters | Backend test logic to add |
|-----|--------|----------------|---------------------------|
| ✅ done | ~~`reviewController.js`~~ | Ratings drive driver trust + auto-complaint/ban thresholds | **Covered** at service layer by `reviewService.test.js` (range, ownership, cancel rules, duplicate, summary). Controller is a thin pass-through. |
| ✅ done | ~~Fare ceiling~~ | Anti-overcharge guard | **Covered** by `fareService.test.js` (`validateFare` blocks above ceiling). NB: `routeController.js` is *route search/popular*, not fare logic. |
| 🟡 P1 | `driverVerificationController.js` | Gatekeeps who can create trips | Pure gate helpers now unit-tested (`*.reupload.test.js`). **Still pending:** supertest for the submit flow — w/o docs → 400; valid → pending; duplicate phone/vehicle → 409; union-active blocks driver path (N-001..N-007) |
| 🟢 P2 | `routeController.js` | Route search/popular listing | supertest: search by q/from/to builds correct filter; only active routes; popular-first ordering |
| 🟡 P1 | `contactLogController.js` | Union contact analytics (whatsapp/phone clicks) | supertest: log click inserts row; bad `type` → 400; stats aggregation returns per-driver counts; non-union-admin → 403 (V-007..V-009) |
| 🟡 P1 | `fcmTokenController.js` | Push delivery depends on token register/dedup | unit/supertest: register token upserts (no dup); invalid token → 400; delete on logout |
| 🟡 P1 | `union/unionPosterController.js` | Poster PDF + 3/day limit (helpers now tested; controller not) | supertest: generate poster → application/pdf; 4th in a day → 400 Hindi msg; other union's schedule → 403 (V-001..V-006) |
| 🟡 P1 | `admin/complaintController.js` | Complaint submit/resolve flow | supertest: submit → 201 open; subject>200/body>2000 → 400; admin resolve → resolved + notify; non-admin list → 403 (T-001..T-012) |
| 🟡 P1 | `admin/adminUserController.js` / `adminStatsController.js` | Admin ban/unban + daily stats | supertest: ban sets restriction + notify; unban lifts; stats endpoint shape; non-admin → 403 |
| 🟢 P2 | `routeController` / `union/unionRouteController` | Route CRUD | supertest CRUD happy-path + ownership checks |
| 🟢 P2 | `middleware/rateLimiter.js` | Rate-limit fallback when Redis down | unit: mock Redis failure → limiter falls back to in-memory, never throws (M-008) |
| 🟢 P2 | `middleware/corsLuha.js` / `requestContext.js` | CORS allow-list + request-id | unit: allowed origin passes, disallowed blocked; requestContext attaches `req.id` |

### W3: Rule — keep stable code safe when adding tests

1. **Run baseline first:** `npm test` and note the green count (currently 510).
2. **Only add, never rewrite** existing passing tests unless the behavior intentionally changed.
3. To unit-test an internal helper, **export it additively** (e.g. `geoBoundingBox` was added to
   `tripSearchController` exports with no behavior change) — never alter the function body.
4. Prefer **pure-function unit tests** (no DB) — fast, deterministic, no flakes.
5. For DB-touching controllers, use **supertest against the monolith app** with a test DB; never point tests at production/staging (they share the prod DB — see CLAUDE.md).
6. **Re-run the full suite** after adding; the new total must be `old + new`, with zero previously-passing tests now failing.

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
  - Trip completed → Hindi title & body shown
  - Rate ride → Hindi title & body shown
  - Booking accepted → Hindi title & body shown
  - Verification approved/rejected → Hindi title & body shown
  - KYC reverify required → Hindi title & body shown
  - Union documents approved → Hindi title & body shown
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

| Order | Type | SOP Parts | When | Who |
|-------|------|-----------|------|-----|
| 1 | Functional + Integration | A, B, E, F, G, H, I | Before every release | Tester / Automated |
| 2 | Security + Rate Limiting + Lockout | C, D, S | Before every release | Tester |
| 3 | KYC / Verification | N, O | Before every release | Tester |
| 4 | Union + Admin + Posters | J, K, V | Before every release | Tester |
| 5 | Complaints + Broadcasts | T | Before every release | Tester |
| 6 | UI/UX | (device testing) | Before every release | Tester (on device) |
| 7 | Localization | L | After any text change | Tester |
| 8 | Notification Flow | Q | Before every release | Tester |
| 9 | Real-Time / Socket.IO | R | Before every release | Tester |
| 10 | Infrastructure + Cleanup | M, P, U | Before deploy | Tester / DevOps |
| 11 | API Regression | All parts | Every push (CI/CD) | Automated (Jest/Newman) |
| 12 | Network / Connectivity | (manual) | Before release | Tester (emulator) |
| 13 | Load / Stress | (k6 scripts) | Before launch + monthly | Tester (k6/Artillery) |
| 14 | Performance Profiling | (DevTools) | Before launch | Tester (DevTools) |
| 15 | Device Compatibility | (real devices) | Before launch | Tester (real devices) |
| 16 | Regression | All parts | Every release | Automated + Manual |

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
