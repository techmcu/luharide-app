# LuhaRide Admin Panel

## Admin Login Credentials

Do **not** commit real passwords in git.

| | |
|---|---|
| **Email** | `admin@luharide.com` |
| **Password** | **(set at creation time / stored in DB)** |

**Demo accounts:** If demo seeder/scripts are used locally, use the credentials printed by the script output (never hardcode in docs).

---

## How to Create Admin

1. Ensure backend is set up and database is running
2. Run from project root:
   ```bash
   cd backend
   node scripts/create-admin.js
   ```
3. Login in the app with the credentials above

---

## Admin Permissions

- **Driver Approvals** – Review documents, Approve or Reject driver verification
- **Create Rides** – Create rides on behalf of drivers (Union)
- **View Dashboard** – Stats, drivers, vehicles, bookings
- **Reports** – Daily, monthly, driver performance (planned)

---

## Driver Verification Flow

1. User submits documents via Profile → Become a Driver
2. Documents appear in Admin → Driver Approvals
3. Admin reviews → Approve (driver gets blue tick) or Reject (with reason)
4. Approved drivers can create rides
