# Manual test checklist — seat booking & ride ownership

Use this list for regression checks after changes to booking, trip details, or payments.

| # | Test case | Expected result |
|---|-----------|-----------------|
| 1 | **Self-book block (driver, home / search / landing)** — Log in as independent driver; create a ride; find it on **Passenger home**, **Search trips**, or **Landing** search; tap **Book** / open trip from list. | Dialog: cannot book your own ride; **no** navigation to trip details (home/search) or same dialog on landing tap. |
| 2 | **Self-book block (driver, trip details)** — Same user opens that ride’s **Trip details** (e.g. from share link or deep link with your trip id). | Bottom shows **amber info bar** (“You posted this ride…”). **No** “Book ride” button. |
| 3 | **Self-book block (seat screen)** — If seat selection ever opens for your own trip (old build / edge case), screen should show warning and **pop back**. | Dialog, then returns to previous screen. |
| 4 | **Self-book block (API)** — Same user calls `POST /api/bookings` with `trip_id` of their own trip (e.g. curl/Postman). | **400** with message that you cannot book your own ride. |
| 5 | **Normal passenger** — Log in as another user; open same ride; **Book ride** → seat selection → confirm. | Booking succeeds or goes pending per trip settings. |
| 6 | **Guest** — Log out; open a ride (if allowed); tap book / login when prompted. | No self-book dialog unless logged-in user id matches `driver.id`. |
| 7 | **Driver seat** — Any user in seat UI: seat **1** not selectable / not bookable. | Already reserved for driver. |

**Implementation note:** Self-book is enforced by comparing **logged-in user id** with **`trips.driver_id`** (API) and **`trip.driver.id`** (app). Deploy backend with `bookingController` change so the API check is live.
