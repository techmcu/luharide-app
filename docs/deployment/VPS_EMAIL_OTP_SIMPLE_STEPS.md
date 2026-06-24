# Email OTP online chalane ke liye – step by step (simple)

Code tumhare VPS pe deploy ho chuka hai. Ab sirf server pe **email settings** add karni hain, phir app se signup pe OTP email aayega.

---

## Step 1: Terminal / CMD kholo

- Windows: **Win + R** dabao, `cmd` likho, Enter  
  ya  
- Cursor/VS Code mein **Terminal** tab kholo

---

## Step 2: VPS pe login karo

Yeh command type karo (Enter dabao):

```
ssh root@76.13.243.157
```

- Pehli baar poochega "Are you sure?" → **yes** likho, Enter  
- Password maange to **VPS ka password** daalo (jo Hostinger se mila tha)

Login ho gaya to screen pe kuch is tarah dikhega: `root@...` (matlab tum server pe ho).

---

## Step 3: .env file kholo

Yeh command type karo:

```
nano /var/www/luharide-backend/backend/.env
```

Enter dabao. Ek file khul jayegi (editor).

---

## Step 4: Email ki 2 lines add karo

File ke **sabse neeche** scroll karo (arrow keys se).

Neeche ye **2 lines** add karo (apna Gmail aur App Password daalna):

```
EMAIL_USER=apna_gmail@gmail.com
EMAIL_APP_PASSWORD=apna_16_character_password
```

**Example (real mat daalna, sirf format samajhne ke liye):**  
Agar Gmail = abc@gmail.com aur App Password = abcd efgh ijkl mnop  
to likho:

```
EMAIL_USER=abc@gmail.com
EMAIL_APP_PASSWORD=abcdefghijklmnop
```

(Spaces mat rakhna password mein – 16 characters ek saath.)

**Gmail App Password kaise banaye:**  
Gmail → Google Account → Security → 2-Step Verification ON → App passwords → "Mail" choose karke 16-character password generate karo.

---

## Step 5: File save karo

- **Ctrl + O** dabao (save)  
- Enter dabao  
- **Ctrl + X** dabao (exit)

---

## Step 6: Backend restart karo

Yeh 2 commands ek ek karke chalao:

```
cd /var/www/luharide-backend/backend
pm2 restart luharide-api
```

Dono ke baad kuch "restarted" jaisa dikhe to theek hai.

---

## Step 7: Test karo

- Phone/emulator pe app kholo  
- **Sign up** pe jao  
- Apna **email** daalo, **Send OTP** dabao  
- Inbox (ya Spam) mein **OTP** aana chahiye  
- Woh OTP + Name + Password daal ke **Verify & Sign Up** karo  

Agar OTP aa gaya aur signup ho gaya to **online chal raha hai**.

---

## Agar problem aaye

- **OTP nahi aaya:**  
  - Spam folder check karo  
  - Step 4 mein `EMAIL_USER` aur `EMAIL_APP_PASSWORD` sahi daale? (no space, full Gmail, 16-char app password)

- **"Connection refused" / login nahi ho raha:**  
  - Step 2 mein VPS ka sahi password use kiya?  
  - Internet theek hai?

- **503 error app mein:**  
  - Matlab server pe email config abhi bhi nahi mili – Step 3–6 dubara karo, specially Step 4.

---

**Short summary:**  
1. CMD kholo → 2. `ssh root@76.13.243.157` → 3. `nano .../.env` → 4. Neeche 2 lines EMAIL_USER aur EMAIL_APP_PASSWORD add karo → 5. Ctrl+O, Enter, Ctrl+X → 6. `cd ... backend` phir `pm2 restart luharide-api` → 7. App se signup test karo.
