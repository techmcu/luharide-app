# VPS pe Email OTP chalane ka checklist

Deploy ke baad VPS pe ye steps karo taaki Signup/Login with Email OTP online chal jaye.

---

## 1. Code deploy (GitHub push)

```bash
cd D:\cur\luharide
git add -A
git commit -m "feat: email OTP signup + VPS checklist"
git push origin main
```

GitHub Actions VPS pe code deploy karega aur `npm run migrate` bhi chalega (016_otp_email_support already included).

---

## 2. VPS pe .env check karo

SSH se VPS pe login karo:

```bash
ssh root@76.13.243.157
```

Backend `.env` dekho:

```bash
cat /var/www/luharide-backend/backend/.env | grep -E "EMAIL|SMTP"
```

**Agar ye lines nahi dikhengi ya empty hon:**

```bash
nano /var/www/luharide-backend/backend/.env
```

**Add / update karo (apna Gmail + App Password daalna):**

```env
# Email OTP (Gmail)
EMAIL_USER=your_gmail@gmail.com
EMAIL_APP_PASSWORD=your_16_char_app_password
```

Save: `Ctrl+O`, Enter, `Ctrl+X`.

---

## 3. API restart

```bash
cd /var/www/luharide-backend/backend
pm2 restart luharide-api
pm2 status
```

---

## 4. (Optional) CLIENT_URL agar domain use kar rahe ho

Agar app **https://luharide.cloud** se chalegi to VPS `.env` mein:

```env
CLIENT_URL=https://luharide.cloud
```

Set karke phir `pm2 restart luharide-api`.

---

## 5. Test

- App se Sign up → Email daalo → Send OTP.
- Inbox/Spam mein OTP aana chahiye.
- OTP + Name + Password daal ke Verify & Sign Up → account banna chahiye.

Agar 503 aaye to matlab VPS `.env` mein `EMAIL_USER` / `EMAIL_APP_PASSWORD` missing ya galat hain.
