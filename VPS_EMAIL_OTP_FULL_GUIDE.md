# VPS pe Email OTP – pura step-by-step guide

Is guide mein tumhare example email aur password use kiye gaye hain. Sirf copy-paste karke steps follow karo.

---

## Step 1: VPS pe login karo

1. **CMD ya PowerShell** kholo (Win + R → `cmd` → Enter).
2. Yeh command type karo (Enter dabao):

   ```
   ssh root@76.13.243.157
   ```

3. Pehli baar "Are you sure?" aaye to **yes** likho, Enter.
4. Password maange to **VPS ka password** daalo (Hostinger wala).
5. Jab `root@...` dikhe to samjho login ho gaya.

---

## Step 2: Check karo – pehle se email lines hain ya nahi

Yeh **ek line** copy karke terminal mein paste karo, Enter dabao:

```bash
grep -E "luharide@gmail.com|ghlrmxpyltpfsaun" /var/www/luharide-backend/backend/.env
```

- **Agar 2 lines dikhen** (EMAIL_USER=... aur EMAIL_APP_PASSWORD=...) → Step 4 pe jao (restart).
- **Agar kuch nahi dikhe** ya sirf 1 line → Step 3 karo (add karna hai).

---

## Step 3: .env file kholo aur 2 lines add karo

**3.1** Yeh command chalao (file khul jayegi):

```bash
nano /var/www/luharide-backend/backend/.env
```

**3.2** Arrow keys se **sabse neeche** jao (last line ke baad).

**3.3** Neeche ye **2 lines** add karo. (Apna email/password ho to badal lena; nahi to copy-paste karo.)

```
EMAIL_USER=luharide@gmail.com
EMAIL_APP_PASSWORD=ghlrmxpyltpfsaun
```

- **Space mat rakhna** `=` ke around.
- Ek line mein `EMAIL_USER=...`, dusri line mein `EMAIL_APP_PASSWORD=...`.

**3.4** File save karo:
- **Ctrl + O** dabao
- **Enter** dabao
- **Ctrl + X** dabao (exit)

---

## Step 4: Backend restart karo

Pehle ye command (Enter):

```bash
cd /var/www/luharide-backend/backend
```

Phir ye command (Enter):

```bash
pm2 restart luharide-api
```

"restarted" jaisa dikhe to theek hai.

---

## Step 5: Test karo

1. Phone/emulator pe **app** kholo.
2. **Sign up** → apna **email** daalo (jo bhi test karna hai) → **Send OTP**.
3. Inbox / Spam mein **OTP** aana chahiye.
4. OTP + Name + Password daal ke **Verify & Sign Up** karo.

---

## Commands summary (copy-paste ke liye)

**Check (email lines hain ya nahi):**
```bash
grep -E "EMAIL_USER|EMAIL_APP_PASSWORD" /var/www/luharide-backend/backend/.env
```

**.env edit (nano):**
```bash
nano /var/www/luharide-backend/backend/.env
```
(Neeche add karo:)
```
EMAIL_USER=luharide@gmail.com
EMAIL_APP_PASSWORD=ghlrmxpyltpfsaun
```
(Save: Ctrl+O → Enter → Ctrl+X)

**Restart:**
```bash
cd /var/www/luharide-backend/backend
pm2 restart luharide-api
```

---

**Note:** Agar tumhara real email/password alag hai to Step 3.3 mein wahi daalna. Format same rahega: `EMAIL_USER=your@gmail.com` aur `EMAIL_APP_PASSWORD=your16charpassword`.

**Admin dashboard:** VPS `.env` mein `ADMIN_EMAIL=orahulpanwar@gmail.com` add karo (apna admin email). Is email se OTP signup/login karoge to app **Admin Dashboard** (Union Admin screen) dikhayegi. Detail: `ADMIN_DASHBOARD_ACCESS.md`.
