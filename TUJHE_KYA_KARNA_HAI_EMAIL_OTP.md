# Email OTP – Tumhe kya karna hai (step-by-step)

Sirf ye steps follow karo, order mein.

---

## Push safe (GitHub pe kya jayega / kya nahi)

| File | Kabhi push hota hai? | Use |
|------|----------------------|-----|
| **`.env`** | **Nahi** – .gitignore mein hai | Yahan **real** Gmail + app password daalna |
| **`.env.example`** | **Haan** – ye template hai | Sirf example/placeholder; real values **.env** mein daalo |

Matlab: tum **`backend/.env`** mein apna asli password daaloge; woh file **kabhi online push nahi hogi**. **`.env.example`** pehle se hi sahi naam hai (sab projects mein aise hi hota hai).

---

## Step 1: Gmail App Password banao

1. Browser mein jao: **https://myaccount.google.com/security**
2. **2-Step Verification** pe click karo → **ON** karo (agar pehle se ON hai to skip).
3. Phir jao: **https://myaccount.google.com/apppasswords**
4. **Select app** → **Mail** choose karo  
   **Select device** → **Other** → name likho: `LuhaRide`  
   **Generate** pe click karo.
5. Jo **16-character password** dikhe, use **copy** karke kahin save kar lo (ye Gmail ka normal password nahi hai, sirf app ke liye).

---

## Step 2: Backend folder mein `.env` set karo

1. Open karo: **`D:\cur\luharide\backend\.env`**
2. **File name:** `backend/.env` (**.env** – yeh wahi file hai jisme tum real values daaloge; ye **kabhi GitHub pe push nahi hoti**).

   Neeche ye 2 lines add karo (apna Gmail aur app password daal kar):

```
EMAIL_USER=apna_gmail@gmail.com
EMAIL_APP_PASSWORD=ghlrmxpyltpfsaun
```

**Example:** Agar app password tha `ghlr mxpy ltpf saun` to space hata ke likho: `ghlrmxpyltpfsaun` (16 characters).

- **EMAIL_USER:** wahi Gmail jis account se app password banaya.
- **EMAIL_APP_PASSWORD:** 16-character code – space ke bina ya space ke saath dono chalega.

3. File **save** karo.

---

## Step 3: Backend run karo

1. Terminal/PowerShell kholo.
2. Ye commands chalao:

```powershell
cd D:\cur\luharide\backend
npm install
npm run dev
```

3. Jab tak **"Server running on port 3000"** ya similar dikhe, tab tak wait karo. Server chal raha hai.

---

## Step 4: Test karo (browser ya Postman)

**A) OTP bhejna (email pe):**

- **URL:** `http://localhost:3000/api/auth/send-otp`  
- **Method:** POST  
- **Body (JSON):**

```json
{"email": "apna_gmail@gmail.com"}
```

- Send karo. Response mein "OTP sent to your email" aana chahiye.
- **Gmail inbox (aur spam)** check karo – 6-digit OTP aaya hoga.

**B) OTP verify karke login/signup:**

- **URL:** `http://localhost:3000/api/auth/verify-otp`  
- **Method:** POST  
- **Body (JSON):** jo OTP aaya (e.g. 482917) aur same email daal kar:

```json
{
  "email": "apna_gmail@gmail.com",
  "otp": "482917",
  "name": "Test User",
  "role": "passenger"
}
```

- Send karo. Response mein **user** aur **tokens** aane chahiye – matlab kaam ho gaya.

---

## Agar error aaye

| Problem | Kya karo |
|--------|----------|
| "Email service not configured" | `.env` mein `EMAIL_USER` aur `EMAIL_APP_PASSWORD` sahi daale? Server restart karo. |
| OTP email nahi aaya | Spam folder dekho. Gmail app password sahi hai? 2-Step Verification ON hai? |
| "Invalid OTP" | Same email se send kiya tha? OTP 10 min ke andar use karo. Naya OTP bhej kar try karo. |
| "Provide either phone or email" | Body mein `email` key zaroor bhejo, e.g. `{"email":"a@b.com"}`. |

---

## Short checklist

- [ ] Gmail 2-Step Verification ON  
- [ ] Gmail App Password banaya aur copy kiya  
- [ ] `backend/.env` mein `EMAIL_USER` aur `EMAIL_APP_PASSWORD` add kiye  
- [ ] `npm run dev` se server chala rahe ho  
- [ ] Send-otp (email) test kiya – email pe OTP aaya  
- [ ] Verify-otp test kiya – user + tokens mile  

Iske baad app se bhi same API call karke login/signup use kar sakte ho. Jab local pe sab theek ho, tab GitHub push karna.
