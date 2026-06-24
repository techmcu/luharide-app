# LuhaRide — Manual Test Cases

> **Purpose:** A-to-Z manual testing checklist for every critical flow.
> Every step has an **Expected Result** so a beginner tester can verify correctness.
> Mark each step PASS / FAIL while testing.

---

## How to Use This Document

1. Open the app (APK or web)
2. Follow each section in order
3. At each step, do the **Action** and check the **Expected Result**
4. Write PASS or FAIL next to each step
5. If FAIL — note what actually happened

---

# SECTION 1: AUTHENTICATION

## TC-1.1: Email Signup (New User)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Open app for the first time | Landing screen shows — search bar, "Sign Up" & "Login" buttons visible | |
| 2 | Tap "Sign Up" | Signup screen opens — Email field, "Send OTP" button visible | |
| 3 | Enter invalid email (e.g. `abc`) → tap "Send OTP" | Error: "Enter a valid email" — OTP not sent | |
| 4 | Enter valid email → tap "Send OTP" | Loading spinner, then success: "OTP sent to your email" — step 2 fields appear (OTP, Name, Password) | |
| 5 | Enter wrong OTP (e.g. `000000`) → tap Sign Up | Error: "Invalid OTP" or "OTP expired" | |
| 6 | Enter correct OTP from email | OTP accepted — no error | |
| 7 | Leave Name empty → tap Sign Up | Error: "Name is required" | |
| 8 | Enter Name, leave Password empty → tap Sign Up | Error: "Password is required" | |
| 9 | Enter short password (e.g. `123`) → tap Sign Up | Error: password too short | |
| 10 | Enter valid Name + valid Password + don't check Terms checkbox → tap Sign Up | Error: must accept terms | |
| 11 | Check Terms checkbox → tap Sign Up | Success — logged in, redirected to Passenger Home Screen | |
| 12 | Check top of screen | User's name shown in greeting | |

## TC-1.2: Email Login (Existing User)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Tap "Login" on landing screen | Login screen — Email & Password fields visible | |
| 2 | Enter wrong email → tap Login | Error: "User not found" or "Invalid credentials" | |
| 3 | Enter correct email, wrong password → tap Login | Error: "Invalid credentials" | |
| 4 | Enter correct email + correct password → tap Login | Success — redirected to Home Screen (based on role) | |

## TC-1.3: Google Sign-In

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | On Signup/Login screen, tap "Sign in with Google" | Google account chooser opens | |
| 2 | Select a Google account | Loading → success — redirected to Home Screen | |
| 3 | Logout → Login again with same Google account | Login success — same profile loaded (name, email from Google) | |

## TC-1.4: Forgot Password

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | On Login screen, tap "Forgot Password?" | Forgot Password screen opens — email field visible | |
| 2 | Enter registered email → tap "Send OTP" | Success: "OTP sent to your email" | |
| 3 | Enter wrong OTP → tap Reset | Error: "Invalid OTP" | |
| 4 | Enter correct OTP + new password + confirm password (mismatch) → tap Reset | Error: "Passwords don't match" | |
| 5 | Enter matching passwords → tap Reset | Success: "Password reset successful" — redirected to Login | |
| 6 | Login with new password | Login success | |

## TC-1.5: Logout

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Go to Profile tab → tap "Logout" | Confirmation dialog: "Are you sure?" | |
| 2 | Tap "Cancel" | Dialog closes, still logged in | |
| 3 | Tap "Logout" (confirm) | Redirected to Landing Screen — no user data visible | |
| 4 | Kill app and reopen | Landing Screen shows (not auto-logged in) | |

## TC-1.6: Language Switching

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Find language toggle (EN/HI) on home screen | Toggle button visible | |
| 2 | Switch to Hindi (HI) | All UI text changes to Hindi immediately | |
| 3 | Switch back to English (EN) | All UI text changes to English | |
| 4 | Set Hindi → close app → reopen | App opens in Hindi (language persisted) | |

---

# SECTION 2: PASSENGER FLOW

## TC-2.1: Search Rides

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | On Home screen, tap "From" location field | Keyboard opens, can type location | |
| 2 | Type a location name (e.g. "Dehradun") | Autocomplete suggestions appear below | |
| 3 | Select a suggestion | Field filled with selected location | |
| 4 | Tap "To" location field → type and select (e.g. "Mussoorie") | "To" field filled | |
| 5 | Tap date field | Date picker opens — only future dates selectable (up to 90 days) | |
| 6 | Select a date → tap OK | Date filled in field | |
| 7 | Tap "Search" without filling From | Error: "From location is required" | |
| 8 | Fill both From & To → tap "Search" | Loading → search results appear (or "No rides found" if none exist) | |
| 9 | Check each result card | Shows: From→To, departure time, fare/seat, available seats, driver name | |
| 10 | Scroll through results | List scrolls smoothly, all cards render correctly | |

## TC-2.2: View Trip Details (Before Booking)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | From search results, tap a trip card | Trip Details screen opens | |
| 2 | Check trip info | Shows: From, To, departure date/time, fare per seat, available seats, vehicle number | |
| 3 | Check driver section | Shows: driver name, verification badge (blue tick if verified), rating stars | |
| 4 | Check driver contact | Phone/WhatsApp button NOT visible (not booked yet) | |
| 5 | Tap "View Ratings & Reviews" on driver | Driver reviews page opens — shows ratings list or "No reviews yet" | |
| 6 | Check stops section | If trip has stops, they are listed in order | |
| 7 | Check luggage info | If driver set luggage allowance, it shows (e.g. "1 bag per passenger") | |

## TC-2.3: Book Seats (Independent Driver Trip)

**Pre-condition:** Your profile must have a phone number (go to Profile → Edit Profile → add phone first).

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | On Trip Details, tap "Book Now" | Seat Selection screen opens — seat map visible | |
| 2 | Check seat map | Seat 1 (driver) is grey/disabled. Other seats show green (available), red (booked), or orange (pending) | |
| 3 | Tap an available (green) seat | Seat turns selected (highlighted), seat count shows "1 seat selected", total fare shows | |
| 4 | Tap another available seat | 2 seats selected, fare = 2 × fare_per_seat | |
| 5 | Tap a selected seat again | Seat deselected — count goes back to 1 | |
| 6 | Tap a booked (red) seat | Nothing happens — cannot select booked seats | |
| 7 | Tap a pending (orange) seat | Nothing happens — cannot select pending seats | |
| 8 | With 1+ seats selected, tap "Confirm Booking" | Loading → Success: "Booking created" | |
| 9 | Check booking status | If trip has `require_approval = true` → status = "Pending" (waiting for driver). If `false` → status = "Confirmed" | |

## TC-2.4: Phone Required Check (Independent Driver Trip)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Remove phone number from profile (Edit Profile → clear phone → save) | Phone field empty in profile | |
| 2 | Open an independent driver's trip | **Orange warning banner** visible at top: "Add your phone number in Profile to book this ride. Tap here to go to Profile." | |
| 3 | Tap the banner | Navigates to Edit Profile screen | |
| 4 | Add phone number (10 digits) → Save | Success: "Profile updated" — navigate back | |
| 5 | Go back to trip details | Orange banner is GONE (phone now exists) | |
| 6 | Go to Seat Selection screen | Orange banner also GONE on seat selection | |
| 7 | Try to book | Booking succeeds (no phone error) | |

## TC-2.5: View My Bookings (Passenger)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Tap "My Bookings" tab on bottom navigation | My Bookings screen — list of all your bookings | |
| 2 | Check each booking card | Shows: trip From→To, date/time, seats booked, status (Pending/Confirmed/Cancelled), fare, driver name | |
| 3 | Find a "Confirmed" booking → tap it | Booking details open | |
| 4 | Check driver contact on confirmed booking | WhatsApp button visible — can tap to open WhatsApp with driver's number | |
| 5 | Find a "Pending" booking → tap it | Shows: "Booking pending — driver contact will be shared once confirmed." | |
| 6 | Pull down to refresh | List refreshes, any status changes reflected | |

## TC-2.6: Cancel Booking (Passenger)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Open a "Pending" booking → tap "Cancel" | Confirmation dialog appears | |
| 2 | Confirm cancel | Success: booking status changes to "Cancelled" — seats freed up | |
| 3 | Open a "Confirmed" booking (departure > 30 min away) → tap "Cancel" | Confirmation dialog → cancel succeeds | |
| 4 | Try to cancel a "Confirmed" booking with departure < 30 min away | Error: "Cancellation not allowed. Cancel at least 30 minutes before departure." | |
| 5 | After cancelling, try to re-book same trip immediately | Error: "You cancelled this ride recently. Please wait X minutes before booking again." (10 min cooldown) | |
| 6 | Wait 10 minutes → try again | Booking succeeds | |

## TC-2.7: Rate & Review Driver (After Trip)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Find a completed trip in My Bookings | "Rate & Review" button visible | |
| 2 | Tap "Rate & Review" | Rating dialog opens — star selection (1-5) + comment field | |
| 3 | Select 0 stars → try submit | Error: must select rating | |
| 4 | Select 4 stars → optionally add comment → tap Submit | Success: "Review submitted" | |
| 5 | Go back to same booking | "Rate & Review" button gone or shows "Already rated" | |
| 6 | View driver's profile/ratings | Your review appears in the list | |
| 7 | Try to submit rating with comment > 20 words | Error: "Comment cannot exceed 20 words" | |
| 8 | Try to rate within 4 minutes of booking confirmation | Error: "You can rate 4 minutes after your ride is confirmed. Please wait." | |
| 9 | Wait 4 minutes → try again | Rating dialog allows submission | |

## TC-2.8: Rate-Ride Notification — Cancelled Booking Must NOT Trigger

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Book a seat on an independent driver trip (confirmed) | Booking confirmed | |
| 2 | Cancel the booking within a few minutes | Booking cancelled successfully | |
| 3 | Wait for rate notification job to run (up to 15 min) | **No** "How was your ride?" notification should arrive | |
| 4 | Check Notifications screen | No rate-ride notification for the cancelled booking | |

## TC-2.9: Rate-Ride Notification — Confirmed Booking Should Trigger

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Book a seat on an independent driver trip (confirmed) | Booking confirmed | |
| 2 | Do NOT cancel — let the ride departure time pass | Booking stays confirmed | |
| 3 | Wait for rate notification job (up to 15 min after send_after time) | "How was your ride?" notification arrives for both passenger and driver | |
| 4 | Tap the notification | Rating dialog opens | |
| 5 | Select stars + comment → tap Submit | Success: "Rating submitted" — no errors | |

## TC-2.10: Rate-Ride Notification — Driver Cancels Trip Before Notification

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Book a seat on a trip (confirmed) | Booking confirmed | |
| 2 | Driver cancels the entire trip | Passenger receives "Ride cancelled" notification, booking cancelled | |
| 3 | Wait for rate notification job to run | **No** "How was your ride?" notification — pending notification cleaned up | |

## TC-2.11: Self-Booking Prevention

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Login as a verified driver | Driver home screen | |
| 2 | Create a trip as this driver | Trip created successfully | |
| 3 | Search for this same trip (switch to passenger view or search) | Trip appears in results | |
| 4 | Try to book your own trip | Error: cannot book your own trip | |

---

# SECTION 3: INDEPENDENT DRIVER FLOW

## TC-3.1: Apply for Driver Verification (KYC)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Login as a passenger (no driver status) | Passenger home screen | |
| 2 | Go to Profile → tap "Become a Driver" | Driver Verification Form opens | |
| 3 | Check form fields | Visible: Contact Phone, Contact Email, Document uploads (Aadhaar front/back, DL front/back), Vehicle Registration, Vehicle Type dropdown | |
| 4 | Leave phone empty → tap Submit | Error: "Mobile number is required" | |
| 5 | Enter 8-digit phone → tap Submit | Error: "Enter valid 10-digit mobile number" | |
| 6 | Enter valid 10-digit phone | Accepted | |
| 7 | Leave email empty → tap Submit | Error: "Email is required" | |
| 8 | Enter invalid email (e.g. `abc`) → tap Submit | Error: "Enter valid email" | |
| 9 | Don't upload any document → tap Submit | Error: "Please upload all required documents" | |
| 10 | Upload Aadhaar Front → check chip | Chip turns green with checkmark | |
| 11 | Upload Aadhaar Back, DL Front, DL Back | All 4 chips green | |
| 12 | Leave Vehicle Registration empty → tap Submit | Error: "Vehicle registration is required" | |
| 13 | Enter vehicle registration (e.g. `UK07AB1234`) | Accepted | |
| 14 | Don't select vehicle type → tap Submit | Error: "Please select a vehicle" | |
| 15 | Select vehicle from dropdown (e.g. "Maruti Ertiga · 6 Seats") | Vehicle selected, seat note appears below | |
| 16 | Fill ALL fields correctly → tap "Submit" | Loading → Success: "Verification request submitted. Admin will review shortly." — navigates back | |
| 17 | Go to Profile → tap "Become a Driver" again | Shows: "Verification Pending" screen with hourglass icon — cannot submit again | |
| 18 | Check "Refresh Status" button | Tap it → still shows "Pending" (until admin acts) | |

## TC-3.2: Phone Saved to Profile After KYC Submit

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Before KYC submit, check Profile → phone field is empty | Phone empty | |
| 2 | Submit KYC with phone `9876543210` | Success | |
| 3 | Go to Edit Profile → check phone field | Phone shows `9876543210` (auto-synced from KYC form) | |

## TC-3.3: Admin Approves Driver → Phone Visible

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Login as Platform Admin | Admin dashboard | |
| 2 | Go to KYC queue → find the pending driver request | Request visible with driver's name, documents | |
| 3 | Review documents → tap "Approve" | Success: "Driver approved" | |
| 4 | Login back as the driver | Role changed to "Driver" — Driver Home Screen shows | |
| 5 | Check Profile | Blue verification tick visible, role shows "Driver" | |
| 6 | Check Edit Profile → phone field | Phone number present (synced from KYC) | |

## TC-3.4: Admin Rejects Driver

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Login as Admin → find pending KYC request → tap "Reject" | Rejection reason field appears | |
| 2 | Enter reason (e.g. "Documents unclear") → confirm | Success: "Request rejected" | |
| 3 | Login as the rejected driver → go to Profile → tap "Become a Driver" | Shows rejection status + reason. "Reupload" button visible (if admin allowed) | |

## TC-3.5: Create Trip (Independent Driver)

**Pre-condition:** Driver must be KYC-approved.

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | On Driver Home, tap "Create Trip" | Create Trip form opens | |
| 2 | Leave "From" empty → tap Create | Error: "From location required" | |
| 3 | Enter From location (e.g. "Dehradun") via autocomplete | From field filled | |
| 4 | Enter To location (e.g. "Mussoorie") | To field filled | |
| 5 | Select a past date | Error or date picker doesn't allow past dates | |
| 6 | Select a future date + time | Accepted | |
| 7 | Leave fare empty → tap Create | Error: fare required | |
| 8 | Enter fare (e.g. `250`) | Accepted | |
| 9 | Check vehicle number field | Auto-filled from KYC (locked/greyed out) | |
| 10 | Check "Require approval" toggle | Default ON — bookings will need your approval | |
| 11 | Optionally add stops | Stops field accepts text | |
| 12 | Tap "Create Trip" | Loading → Success: "Trip created" — redirected to My Trips | |
| 13 | Check My Trips list | New trip appears at top with status "Scheduled" | |

## TC-3.6: Manage Bookings (Driver Accept/Reject)

**Pre-condition:** A passenger has booked your trip (with `require_approval = true`).

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | On Driver Home → check notifications | Notification: "New booking request" with passenger name | |
| 2 | Go to My Trips → find trip with pending badge (orange count) | Badge shows number of pending bookings | |
| 3 | Tap trip → open Driver Trip Details | Passenger list visible with "Pending" bookings | |
| 4 | Check passenger info | Name, seats requested, booking time visible | |
| 5 | Tap "Reject" on a booking | Confirmation → booking cancelled, seats freed | |
| 6 | Tap "Accept" on another booking | Booking status → "Confirmed", passenger gets notification | |
| 7 | Check seat map | Accepted seats show as booked (red), rejected seats back to available (green) | |

## TC-3.7: Trip Lifecycle (Start → Complete)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Open your scheduled trip with confirmed bookings | "Start Trip" button visible | |
| 2 | Tap "Start Trip" | Confirmation → trip status changes to "In Progress" | |
| 3 | Check: any PENDING bookings that were not accepted | They should be auto-cancelled (passenger notified) | |
| 4 | After ride is done → tap "Complete Trip" | Confirmation → trip status changes to "Completed" | |
| 5 | Check My Trips | Trip shows under "Completed" filter | |

## TC-3.7a: Independent Ride Auto-Complete (No Manual Button Needed)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Create an independent driver trip with departure time 5 min in the future | Trip created with status "Scheduled" | |
| 2 | Wait for departure time to pass | Trip still shows "Scheduled" immediately (job runs every 30 min) | |
| 3 | Wait for auto-complete job to run (up to 30 min after departure) | Trip status automatically changes to "Completed" | |
| 4 | Check My Trips — refresh the list | Trip now shows "Completed" tag — no manual action needed | |
| 5 | Check: passenger side (My Bookings) | Booking also reflects completed trip | |
| 6 | Create a trip with departure time 1 hour in the future → manually complete it before auto-complete runs | "Complete ride" button works as usual — no conflict | |
| 7 | Check: union admin trip (not independent) with past departure | Auto-complete does **NOT** apply — union trips are not affected by this job | |

## TC-3.8: Cancel Trip (Driver) — Rules

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Create a trip with departure tomorrow, NO bookings → open 3-dot menu | "Cancel trip" option visible (scheduled + future departure) | |
| 2 | Tap "Cancel trip" → confirm | Success: trip status = "Cancelled", removed from active rides | |
| 3 | Create trip with departure tomorrow → passenger books and gets confirmed | Trip has confirmed booking | |
| 4 | Open 3-dot menu → tap "Cancel trip" (departure > 2 hours away) | Success: trip cancelled, **all bookings cancelled**, passenger receives notification | |
| 5 | Create trip with departure 1 hour from now → passenger books and gets confirmed | Trip has confirmed booking, departure < 2 hours | |
| 6 | Open 3-dot menu → tap "Cancel trip" | Error: "Cannot cancel trip. Driver cannot cancel within 2 hours of departure when passengers are confirmed." | |
| 7 | Create trip with departure 1 hour from now, NO bookings → cancel | Success: cancellation allowed (no confirmed passengers, cutoff rule doesn't apply) | |
| 8 | Open a trip whose departure time has already passed | "Cancel trip" option **NOT visible** in 3-dot menu (only "Delete ride" shows) | |
| 9 | Open an "in_progress" trip | "Cancel trip" option **NOT visible** (only scheduled trips can be cancelled) | |
| 10 | Cancel a trip that has pending + confirmed bookings | **Both** pending and confirmed bookings cancelled, all passengers notified | |

## TC-3.8a: Delete Ride (Driver) — Rules

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Create a trip with NO bookings → open 3-dot menu | "Delete ride (no bookings only)" option visible | |
| 2 | Tap "Delete ride" → confirm | Success: trip permanently deleted from system, gone from My Trips | |
| 3 | Create trip → passenger books (pending) → try delete | Error: "Cannot delete ride. X booking request(s) are pending. Please accept or reject them first." | |
| 4 | Create trip → passenger books (confirmed) → try delete | Error: "Cannot delete ride. X seat(s) are already booked. Passengers would be affected." | |
| 5 | Create trip → passenger books (confirmed) → passenger cancels → try delete now | Success: all bookings are cancelled, so delete works (0 active bookings) | |
| 6 | Delete a completed trip with no active bookings | Success: trip deleted | |
| 7 | Verify after delete: trip not in search results, not in driver My Trips | Trip completely gone — no trace | |

## TC-3.9: Role Exclusivity — Driver Cannot Register Union

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Login as an approved independent driver | Driver home screen | |
| 2 | Go to Profile → look for "Register Union" option | Option NOT visible OR shows blocked message: "Independent driver verification is active on this account" | |

---

# SECTION 4: UNION ADMIN FLOW

## TC-4.1: Register a Taxi Union

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Login as a new user (no driver verification) | Passenger home screen | |
| 2 | Go to Profile → tap "Register Union" | Union Registration form opens | |
| 3 | Leave union name empty → tap Submit | Error: "Union name must be at least 3 characters" | |
| 4 | Enter union name (e.g. "Dehradun Taxi Union") | Accepted | |
| 5 | Enter location | Accepted | |
| 6 | Leave phone empty → tap Submit | Error: "Mobile number is required" | |
| 7 | Enter invalid phone (e.g. `12345`) → tap Submit | Error: "Enter valid 10-digit mobile number" | |
| 8 | Enter valid 10-digit phone | Accepted | |
| 9 | Enter valid email | Accepted | |
| 10 | Enter owner name | Accepted | |
| 11 | Upload required documents (Aadhaar front/back, office photo, RC etc.) | Chips turn green | |
| 12 | Tap "Submit Registration" | Loading → Success: "Union registration submitted. Admin will review." | |
| 13 | Go to Profile → tap "Register Union" again | Shows "Registration Pending" with hourglass | |

## TC-4.2: Phone Saved to Profile After Union Registration

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Before registration, Edit Profile → phone is empty | Phone empty | |
| 2 | Register union with phone `9876543210` | Success | |
| 3 | Go to Edit Profile → check phone | Phone shows `9876543210` (auto-synced) | |

## TC-4.3: Admin Approves Union

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Login as Platform Admin → find pending union registration | Union request visible | |
| 2 | Review documents → tap "Approve" | Success | |
| 3 | Login as union admin user | Role changed to "Union Admin" — Union Admin Home Screen | |
| 4 | Check Profile | Shows union admin role, union name visible | |

## TC-4.4: Add Drivers to Union

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | On Union Admin Home → go to "Manage Drivers" | Empty list or existing drivers shown | |
| 2 | Tap "Add Driver" (+ button) | Add Driver form/modal opens | |
| 3 | Leave name empty → tap Add | Error: name required | |
| 4 | Enter driver name + vehicle number + phone (10 digits) | All fields valid | |
| 5 | Optionally enter WhatsApp number | Accepted | |
| 6 | Tap "Add" | Success: driver added to list | |
| 7 | Check driver in list | Shows: name, vehicle number, phone — call & WhatsApp buttons visible | |
| 8 | Tap Call button on a driver | Phone dialer opens with driver's number | |
| 9 | Tap WhatsApp button on a driver | WhatsApp opens with driver's number | |

## TC-4.5: Remove Driver from Union

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | On Manage Drivers → find a driver → tap Delete/Remove | Confirmation dialog | |
| 2 | Confirm removal | Driver removed from list | |

## TC-4.6: Create Union Trip (Assign Driver)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Go to Create Trip (from Union Admin Home) | Create Trip form — includes Driver Assignment dropdown | |
| 2 | Fill from/to locations, date, time, fare | All fields valid | |
| 3 | Select a driver from dropdown | Driver selected (name + vehicle shown) | |
| 4 | Tap "Create Trip" | Success: trip created | |
| 5 | Check the trip in search results (as a passenger) | Trip shows with assigned driver's name and contact | |

## TC-4.7: Union Routes Management

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Go to "Routes" from Union Admin Home | Routes list (may be empty) | |
| 2 | Tap "Add Route" | Route creation form — From + To fields | |
| 3 | Enter From & To → Save | Route created, appears in list | |
| 4 | When creating a trip, check route dropdown | Saved routes appear for quick selection | |

## TC-4.8: Poster Generation

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Go to Union Dashboard → Poster section | Poster customization options visible | |
| 2 | Set poster header text | Text accepted | |
| 3 | Set custom text + position (left/right) | Options saved | |
| 4 | Select theme (saffron etc.) | Theme applied | |
| 5 | Tap "Generate Poster" / "Download" | Poster PDF/image generated and downloaded | |
| 6 | Open downloaded poster | Shows: union name, route info, driver contact, custom branding | |

## TC-4.9: Role Exclusivity — Union Admin Cannot Become Independent Driver

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Login as approved union admin | Union Admin home | |
| 2 | Go to Profile → look for "Become a Driver" | Shows blocked message: "Taxi union registration is active on this account." | |

---

# SECTION 5: PROFILE MANAGEMENT

## TC-5.1: Edit Profile

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Go to Profile → tap "Edit Profile" | Edit Profile screen — fields: Avatar, Name, Email, Phone, WhatsApp, Bio | |
| 2 | Clear Name → tap Save | Error: "Name is required" | |
| 3 | Enter a new name → tap Save | Success: "Profile updated" — name changes everywhere | |
| 4 | Enter invalid email → tap Save | Error: invalid email format | |
| 5 | Enter 8-digit phone → tap Save | Error: invalid phone number | |
| 6 | Enter valid 10-digit phone → tap Save | Success: phone updated | |
| 7 | Add WhatsApp number → Save | Success: WhatsApp number saved | |
| 8 | Enter bio > 20 words → Save | Error: "Bio must be at most 20 words" | |
| 9 | Enter bio <= 20 words → Save | Success: bio saved | |
| 10 | Tap profile avatar → pick image from gallery | Image preview shows | |
| 11 | Save with new image | Profile image updated | |

## TC-5.2: Change Password

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Profile → "Change Password" | Change Password screen opens | |
| 2 | Enter wrong current password → tap Save | Error: "Current password is incorrect" | |
| 3 | Enter correct current + new password (too short) → Save | Error: password too short | |
| 4 | Enter valid current + new + confirm (mismatch) → Save | Error: "Passwords don't match" | |
| 5 | Enter valid current + matching new passwords → Save | Success: "Password changed" | |
| 6 | Logout → Login with new password | Login succeeds | |

## TC-5.3: View Submitted Documents

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Profile → "Submitted Documents" (driver only) | List of submitted KYC documents | |
| 2 | Check each document | Shows: type (Aadhaar, DL, RC), status (pending/approved) | |
| 3 | Tap "View" on a document | Document image opens with watermark | |

## TC-5.4: View My Ratings

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Profile → "My Ratings" (driver only) | Ratings screen — average rating + review list | |
| 2 | Check review cards | Each shows: reviewer name, star rating, comment, date | |
| 3 | Pull to refresh | List refreshes | |

---

# SECTION 6: NOTIFICATIONS

## TC-6.1: Booking Notifications

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Passenger books a driver's trip | **Driver receives** notification: "New booking request" | |
| 2 | Driver accepts booking | **Passenger receives** notification: "Booking confirmed" | |
| 3 | Driver rejects booking | **Passenger receives** notification: "Booking rejected/cancelled" | |
| 4 | Passenger cancels a booking | **Driver receives** notification: "A passenger cancelled their booking" | |

## TC-6.2: Trip Notifications

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Driver starts a trip | **Passengers with confirmed bookings** receive notification | |
| 2 | Driver starts a trip with PENDING bookings | Pending bookings auto-cancelled — passengers get "Booking not confirmed" notification | |
| 3 | Driver cancels a trip | All passengers with bookings receive cancellation notification | |
| 4 | Platform admin cancels a trip | Both driver AND passengers receive cancellation notification | |

## TC-6.2a: Rate-Ride Notifications (Timing & Cleanup)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Booking confirmed on independent trip (departure tomorrow) | Rate notification scheduled for departure_time + 5 hours | |
| 2 | Booking confirmed on union/legacy trip | Rate notification scheduled for NOW + 5 hours | |
| 3 | Wait for scheduled time → notification fires | Both passenger and driver get "How was your ride?" / "Rate your passenger" notification | |
| 4 | Tap rate notification → select stars → submit | Rating saved successfully, no errors | |
| 5 | Passenger cancels booking BEFORE notification fires | Pending rate notification deleted — no notification sent later | |
| 6 | Driver cancels entire trip BEFORE notification fires | All pending rate notifications for trip's bookings deleted | |
| 7 | Admin cancels trip BEFORE notification fires | Same cleanup — no stale notifications | |
| 8 | Booking was cancelled but notification already sent (edge case) | Backend rejects rating with "Booking not found" or "Can only rate after booking is confirmed" — app shows clean error, no crash | |

## TC-6.3: KYC Notifications

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Admin approves driver verification | **Driver receives** notification: "Verification Approved — You can now create rides" | |
| 2 | Admin rejects driver verification | Driver receives notification with rejection reason | |

## TC-6.4: Notification UI

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Check notification bell icon | Shows unread count badge (red circle with number) | |
| 2 | Tap notification bell | Notifications list opens | |
| 3 | Check unread notifications | Highlighted/bold compared to read ones | |
| 4 | Tap a notification | Navigates to relevant screen (booking/trip/etc.) + marked as read | |
| 5 | Tap "Mark All as Read" | All notifications become read — badge count becomes 0 | |
| 6 | Pull to refresh | New notifications load | |

---

# SECTION 7: PLATFORM ADMIN

## TC-7.1: Admin Dashboard

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Login as platform admin (`isAppAdmin = true`) | Admin Home Screen — dashboard with tabs | |
| 2 | Check Dashboard tab | Shows: Total Users, Total Drivers, Total Trips, Total Revenue, Pending KYC count | |
| 3 | Numbers should match actual data | Cross-verify counts are reasonable | |

## TC-7.2: User Management

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Go to Users tab | List of all users — search bar visible | |
| 2 | Search by name | Filtered results matching name | |
| 3 | Filter by role (Passenger/Driver/Union Admin) | Only matching roles shown | |
| 4 | Tap a user | User detail screen — name, email, phone, role, status, KYC info | |
| 5 | Tap "Toggle Active/Inactive" | User status toggles | |

## TC-7.3: KYC Review Queue

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Go to KYC queue | List of pending driver verification requests | |
| 2 | Tap a request | KYC Preview screen — all documents visible with watermarks | |
| 3 | Check documents | Aadhaar (front/back), DL (front/back), vehicle info, contact info shown | |
| 4 | Tap "Approve" | Success: driver approved — request removed from queue | |
| 5 | Tap "Reject" on another request → enter reason → confirm | Success: request rejected — removed from queue | |

## TC-7.4: Trip Management

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Go to Trips tab | List of all trips | |
| 2 | Filter by status (Scheduled/In Progress/Completed) | Correct filter applied | |
| 3 | Tap a trip | Trip detail — full info + bookings list | |

---

# SECTION 8: REAL-TIME & SOCKET FEATURES

## TC-8.1: Real-Time Seat Updates

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Open a trip's seat selection on Device A (as Passenger 1) | Seat map shows current availability | |
| 2 | On Device B (as Passenger 2), book 2 seats on the same trip | Booking succeeds | |
| 3 | Check Device A without refreshing | Seats booked by Passenger 2 should update automatically (turn red/orange) via WebSocket | |

## TC-8.2: Booking Status Real-Time Update

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Passenger books trip → status = "Pending" | Pending shown on passenger's screen | |
| 2 | Driver accepts the booking (from driver app) | Passenger's screen updates to "Confirmed" (real-time or on refresh) | |

---

# SECTION 9: EDGE CASES & SECURITY

## TC-9.1: Duplicate Booking Prevention

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Book seat 3 on a trip | Booking created | |
| 2 | Quickly tap "Confirm Booking" again (double-tap) | Only 1 booking created — idempotency key prevents duplicate | |
| 3 | Try booking the same seats again (navigate back and try) | Error: seats already taken or duplicate booking detected | |

## TC-9.2: Expired/Full Trip Booking

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Find a trip with 0 available seats | Seat map shows all seats booked | |
| 2 | Try to book | Error: no available seats | |
| 3 | Find a trip with departure in the past | "Book Now" should be disabled or error on attempt | |

## TC-9.3: Concurrent Booking Conflict

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Two passengers try to book the SAME seat at the SAME time | Only one succeeds — the other gets "Seat no longer available" | |

## TC-9.4: Invalid Token / Session Expired

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Login → wait for token to expire (or manually clear token from storage) | Next API call → auto-refresh token, or redirect to login if refresh fails | |

## TC-9.5: Network Error Handling

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Turn off internet → try to search rides | Error message: "No internet connection" or "Network error" | |
| 2 | Turn internet back on → retry | Search works normally | |

## TC-9.6: Rate Limiting

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Send 10+ OTP requests rapidly | After a few, error: "Too many requests, please try again later" | |
| 2 | Wait a minute → try again | OTP sends normally | |

## TC-9.7: Pending Booking Auto-Expiry Near Departure

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Driver creates trip with `require_approval = true`, departure 5 min from now | Trip created | |
| 2 | Passenger books a seat → status = "Pending" | Booking created as pending | |
| 3 | Driver does NOT accept/reject | Booking stays pending | |
| 4 | Wait until departure time arrives (within 1 min) | Pending booking auto-cancelled by system, seats restored, passenger notified: "Booking not confirmed" | |
| 5 | Check trip's available seats after auto-cancel | Seats restored to original count | |

## TC-9.8: Booking Cooldown After Cancel

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Book a seat → cancel it immediately | Cancel succeeds | |
| 2 | Try to book same trip again within 10 minutes | Error: "You cancelled this ride recently. Please wait X minutes before booking again." | |
| 3 | Wait for cooldown to expire → book again | Booking succeeds | |

## TC-9.9: Driver Cancel Trip Within 2-Hour Cutoff (No Passengers)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Create trip with departure 30 min from now, NO bookings | Trip created | |
| 2 | Cancel the trip | Success — allowed because no confirmed passengers (2hr cutoff only applies with confirmed passengers) | |

## TC-9.10: Double-Rating Prevention

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Rate a completed booking (passenger rates driver) | Rating submitted successfully | |
| 2 | Try to rate the same booking again | Error: "You have already rated for this ride" | |
| 3 | Check: driver also rates the passenger for same booking | Success — each party rates once, independently | |
| 4 | Driver tries to rate same passenger again | Error: "You have already rated for this ride" | |

## TC-9.11: Rating Before Booking is Confirmed (Timing Guard)

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Book a trip with `require_approval = true` → booking = "Pending" | Booking pending | |
| 2 | Try to rate via notification deep link (if somehow received) | Error: "Can only rate after booking is confirmed" | |

## TC-9.12: No BlaBlaCar or Third-Party Branding

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Open driver trip details → 3-dot menu | Menu says "Cancel trip" (not "Cancel trip (BlaBlaCar-style)") | |
| 2 | Open cancel trip confirmation dialog | Text does NOT mention "BlaBlaCar" anywhere | |
| 3 | Check all error messages from cancel/delete operations | No "BlaBlaCar" text in any error message | |
| 4 | Search entire app UI for "BlaBlaCar" | Zero results — no third-party branding visible anywhere | |

## TC-9.13: Invalid UUID in Trip/Booking URLs

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Try to access trip details with invalid ID (e.g. `abc123`) | Error: "Invalid trip ID" — no server crash | |
| 2 | Try to access booking with invalid ID | Error: "Invalid booking ID" — no server crash | |
| 3 | Try to rate a booking with random UUID that doesn't exist | Error: "Booking not found" — clean error, no crash | |

## TC-9.14: Seat Conflict Between Accept and Auto-Cancel

| # | Action | Expected Result | Status |
|---|--------|-----------------|--------|
| 1 | Two passengers each book the same seat (pending) on a `require_approval` trip | Both bookings created as pending | |
| 2 | Driver accepts Passenger 1's booking | Passenger 1 confirmed. Passenger 2's booking auto-cancelled (conflicting seat) | |
| 3 | Check Passenger 2's notification | "Booking cancelled — seat no longer available" or similar | |
| 4 | Check available seats | Correctly reflects only Passenger 1's booking | |

---

# SECTION 10: DATA VALIDATION SUMMARY

## TC-10.1: Field Validation Reference

| Field | Valid Input | Invalid Input → Error |
|-------|-----------|----------------------|
| Email | `user@example.com` | `abc` → "Enter valid email" |
| Phone | `9876543210` (10 digits) | `12345` → "Enter valid 10-digit number" |
| Password | `MyPass123!` (8+ chars) | `123` → "Password too short" |
| Name | `Rahul Sharma` | Empty → "Name is required" |
| Bio | `I am a safe driver` (≤20 words) | 25+ words → "Bio must be at most 20 words" |
| Fare | `250` (positive number) | `0` or empty → "Fare is required" |
| Vehicle Reg | `UK07AB1234` | Empty → "Vehicle registration required" |
| Union Name | `Dehradun Union` (3+ chars) | `AB` → "Must be at least 3 characters" |
| OTP | `123456` (6 digits) | `000` → "Invalid OTP" |
| Date | Future date (≤90 days) | Past date → not selectable |
| Seats | 1 to available count | 0 or > available → error |

---

# SECTION 11: COMPLETE USER JOURNEY TESTS

## TC-11.1: Full Passenger Journey (End-to-End)

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 1 | Open app → Signup with email OTP | Account created, logged in as Passenger | |
| 2 | Edit Profile → add name, phone, photo | Profile complete | |
| 3 | Search ride: Dehradun → Mussoorie, tomorrow | Results show available rides | |
| 4 | Tap a ride → view details | Trip details with driver info visible | |
| 5 | Tap "Book Now" → select 2 seats → Confirm | Booking created (Pending or Confirmed) | |
| 6 | Check My Bookings | Booking visible with correct details | |
| 7 | Wait for driver to accept (if pending) | Status changes to "Confirmed" + notification | |
| 8 | Check driver contact | WhatsApp button visible → opens WhatsApp | |
| 9 | After trip completes | "Rate & Review" option appears | |
| 10 | Rate driver 5 stars + comment → Submit | Review saved successfully | |

## TC-11.2: Full Independent Driver Journey (End-to-End)

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 1 | Signup with email → logged in as Passenger | Account created | |
| 2 | Profile → "Become a Driver" | KYC form opens | |
| 3 | Fill form: phone, email, documents, vehicle | All fields valid | |
| 4 | Submit KYC | "Verification submitted" — status = Pending | |
| 5 | Check Profile → phone | Phone auto-synced from KYC form | |
| 6 | (Admin approves KYC) | Role changes to Driver, blue tick appears | |
| 7 | Check phone after approval | Phone still present in profile | |
| 8 | Create Trip: Dehradun → Mussoorie, tomorrow, fare 250 | Trip created with status "Scheduled" | |
| 9 | (Passenger books a seat) | Notification: "New booking request" | |
| 10 | Open trip → see pending booking → tap "Accept" | Booking confirmed — passenger notified | |
| 11 | Check passenger contact | Passenger's phone visible in booking details | |
| 12 | Wait for departure time to pass | Trip auto-completes to "Completed" (within 30 min of departure) | |
| 13 | Check My Trips | Trip shows "Completed" — no manual button needed | |
| 14 | "How was your ride?" notification arrives | Both driver and passenger get rate notification | |
| 15 | Tap notification → rate passenger | Rating submitted successfully | |

## TC-11.3: Full Union Admin Journey (End-to-End)

| # | Step | Expected Result | Status |
|---|------|-----------------|--------|
| 1 | Signup with email → logged in as Passenger | Account created | |
| 2 | Profile → "Register Union" | Union Registration form opens | |
| 3 | Fill: union name, location, phone, email, owner name, all documents | All fields valid | |
| 4 | Submit registration | "Registration submitted" — status = Pending | |
| 5 | Check Profile → phone | Phone auto-synced from registration form | |
| 6 | (Admin approves union) | Role changes to Union Admin | |
| 7 | Go to "Manage Drivers" → Add a driver (name, vehicle, phone) | Driver added to union | |
| 8 | Create trip → assign the added driver | Trip created with driver assigned | |
| 9 | (Passenger searches and finds this trip) | Trip visible in search results | |
| 10 | (Passenger books a seat) | Booking created | |
| 11 | Check Union Dashboard | Stats update — trips, bookings count | |
| 12 | Generate a poster for a route | Poster PDF generated with union branding | |

---

# SECTION 12: QUICK SMOKE TEST (5-MINUTE CHECK)

> Run this after every new build to quickly verify nothing is broken.

| # | Check | Expected Result | Status |
|---|-------|-----------------|--------|
| 1 | App opens without crash | Landing screen visible | |
| 2 | Login with existing account | Home screen loads | |
| 3 | Search a ride | Results appear or "No rides found" (no crash) | |
| 4 | Open a trip detail | Screen loads with all sections | |
| 5 | Go to Profile | Profile screen loads with correct user info | |
| 6 | Switch language EN → HI → EN | UI text changes correctly | |
| 7 | Check notifications | Notifications screen loads | |
| 8 | Logout | Returns to landing screen | |

---

# SECTION 13: BUILD & DEPLOY CHECKS

| # | Check | Expected Result | Status |
|---|-------|-----------------|--------|
| 1 | `flutter analyze --no-fatal-infos` | 0 errors (info warnings OK) | |
| 2 | `flutter test` | All tests pass | |
| 3 | `npm test --ci` (backend) | All tests pass | |
| 4 | APK installs on Android device | App opens and runs | |
| 5 | Web build opens in browser | App loads at `/app/` path | |
| 6 | Staging deploy (auto on push) | CI passes, staging health check passes | |
| 7 | Production deploy (manual) | All health checks pass, rollback works if failure | |

---

> **Total Test Cases: 200+**
> **Critical Priority:** Sections 1-4, 9, 11
> **Medium Priority:** Sections 5-8, 10
> **Run After Every Build:** Section 12
