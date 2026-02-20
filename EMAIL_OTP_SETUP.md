# LuhaRide – Email OTP Login/Signup Setup (A to Z)

## What’s done in code

- **Send OTP:** `POST /api/auth/send-otp` accepts **email** or **phone**.
- **Verify OTP:** `POST /api/auth/verify-otp` accepts **(email + otp)** or **(phone + otp)**. New user: send **name** and **role**.
- **Email:** Sent via Nodemailer (Gmail SMTP). OTP valid **10 minutes**, one-time use, no OTP in production logs.
- **DB:** Migration `016_otp_email_support.sql` adds `email` to `otp_verifications` and makes `phone` nullable.

---

## What you need to do (your end)

### 1. Gmail App Password (for Email OTP)

1. Use a **Google Account** (Gmail).
2. Turn on **2-Step Verification**:  
   https://myaccount.google.com/security → **2-Step Verification** → turn ON.
3. Create **App password**:  
   https://myaccount.google.com/apppasswords  
   - Select app: **Mail**  
   - Select device: **Other** → name it e.g. "LuhaRide"  
   - Click **Generate**  
   - Copy the **16-character password** (no spaces).
4. Keep this password safe; you’ll put it in `.env` next.

---

### 2. Backend `.env` (local and VPS)

In `backend/.env` add or set:

```env
# Email OTP (Gmail)
EMAIL_USER=your_gmail@gmail.com
EMAIL_APP_PASSWORD=xxxx xxxx xxxx xxxx
```

- `EMAIL_USER`: same Gmail address used for the App Password.
- `EMAIL_APP_PASSWORD`: the 16-character app password (spaces optional).

Optional (only if you use another SMTP):

```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
EMAIL_FROM=LuhaRide <your_gmail@gmail.com>
```

---

### 3. Install dependency and run migration

**Local:**

```bash
cd backend
npm install
npm run migrate
```

**VPS (after deploy):**

Deploy already runs `npm run migrate`. If you added migration 016 after last deploy, either push and let the workflow run, or SSH and run:

```bash
cd /var/www/luharide-backend/backend
npm run migrate
pm2 restart luharide-api
```

---

### 4. Test Email OTP

**Send OTP (email):**

```bash
curl -X POST http://localhost:3000/api/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"your_email@gmail.com"}'
```

Check inbox (and spam). You should get a 6-digit OTP.

**Verify OTP and login/register:**

```bash
curl -X POST http://localhost:3000/api/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"your_email@gmail.com","otp":"123456","name":"Test User","role":"passenger"}'
```

- **Existing user:** only `email` + `otp` needed; `name`/`role` optional.
- **New user:** `name` and `role` required.

**Phone OTP (unchanged):**

- Send: `{"phone":"9876543210"}` to `/api/auth/send-otp`.
- Verify: `{"phone":"9876543210","otp":"123456",...}` to `/api/auth/verify-otp`.

---

### 5. Mobile app (your end)

- **Send OTP:** Call `POST /api/auth/send-otp` with body `{ "email": "user@example.com" }` (or `phone`).
- **Verify OTP:** Call `POST /api/auth/verify-otp` with `{ "email", "otp" }` (or `phone`, `otp`). For new user include `name` and `role`.
- Use the returned **tokens** and **user** for authenticated requests and app state.

---

### 6. Security / loopholes covered

- **Rate limiting:** Existing `otpLimiter` on send-otp (no OTP spam).
- **OTP expiry:** 10 minutes; after that verify returns error.
- **One-time use:** OTP row marked verified; same OTP cannot be reused.
- **Attempts:** After 5 wrong verify attempts for same OTP, user must request a new OTP.
- **No OTP in logs:** Production never logs the OTP value.
- **Validation:** Joi validates email/phone and 6-digit OTP; either phone or email required (not both at once).

---

### 7. Checklist

| Step | Done |
|------|------|
| Gmail 2-Step Verification ON | ☐ |
| Gmail App Password created and copied | ☐ |
| `EMAIL_USER` and `EMAIL_APP_PASSWORD` in `backend/.env` | ☐ |
| `npm install` and `npm run migrate` in backend | ☐ |
| Send-OTP (email) test successful | ☐ |
| Verify-OTP (email) test successful | ☐ |
| On VPS: same env vars + migrate if needed | ☐ |
| Mobile uses send-otp and verify-otp with email | ☐ |

---

## Summary

- **Backend:** Email OTP is implemented and wired; you only need Gmail App Password and `.env`.
- **You:** Set Gmail App Password, add env vars, run migrate, test with curl, then point the app to send/verify OTP by email (or keep phone as before).

---

## Tumhe kya karna hai (short)

1. **Gmail App Password banao** (upar Step 1).
2. **`backend/.env` mein daalo:** `EMAIL_USER=your@gmail.com`, `EMAIL_APP_PASSWORD=16charpassword`.
3. **VPS pe:** Same env vars add karo (e.g. `nano /var/www/luharide-backend/backend/.env`), phir `npm run migrate` + `pm2 restart luharide-api`.
4. **Mobile:** Send OTP pe `email` bhejo; Verify OTP pe `email` + `otp` (+ new user ke liye `name`, `role`).
5. **Test:** Curl se send-otp aur verify-otp dono test karo.
