# Admin dashboard – kaise open karein

**Admin panel** wohi **Union Admin** screen hai (driver verification, requests, etc.). Sirf woh user open kar sakta hai jiska **role = union_admin** hai.

---

## 1. Kaun admin ban sakta hai?

Backend `.env` mein ek email set hota hai: **ADMIN_EMAIL**.  
Jis email ko tum yahan daalte ho, wohi email **admin** ban jati hai (signup ya login ke baad).

**Example:**  
`ADMIN_EMAIL=orahulpanwar@gmail.com`  
→ **orahulpanwar@gmail.com** se jo bhi signup/login karega, usko **Admin Dashboard** milega.

---

## 2. Backend pe ADMIN_EMAIL set karo

**Local (PC):**  
`backend/.env` mein add karo:
```env
ADMIN_EMAIL=orahulpanwar@gmail.com
```

**VPS:**  
SSH → `nano /var/www/luharide-backend/backend/.env` → same line add karo → save → `pm2 restart luharide-api`.

---

## 3. Admin dashboard kaise open karein

**Option A – OTP (Sign up / Login with OTP)**  
1. App mein **Sign up** (ya **Login** agar pehle se account hai).  
2. Email daalo: **orahulpanwar@gmail.com**.  
3. **Send OTP** → OTP daalo → (signup pe) Name + Password set karo → **Verify & Sign up** (ya Verify & login).  
4. Login ke baad app **role** dekhti hai: agar **union_admin** hai to seedha **Admin / Union Admin** wala screen (Admin Dashboard) open ho jata hai.

**Option B – Email + Password (agar pehle se password set hai)**  
1. **Login** → Email: **orahulpanwar@gmail.com**, Password: jo signup pe set kiya tha.  
2. Agar backend pe **ADMIN_EMAIL=orahulpanwar@gmail.com** set hai to login ke time hi DB mein is user ka role **union_admin** kar diya jata hai (agar pehle nahi tha).  
3. Phir app **Admin Dashboard** dikhayegi.

---

## 4. Pehli baar admin banana

- **Naya user:**  
  **Sign up** with **orahulpanwar@gmail.com** (OTP flow) → backend automatically is email ko **union_admin** bana deta hai (jab ADMIN_EMAIL yahi ho).  
  Usi session mein **Admin Dashboard** open ho jata hai.

- **Pehle se passenger wala account:**  
  Agar **orahulpanwar@gmail.com** se pehle **passenger** ban chuka hai, to:  
  - **Login** karo isi email se (OTP ya password).  
  - Backend is login pe is email ko **union_admin** bana deta hai (ADMIN_EMAIL match hone pe).  
  - Agli baar app open karoge to **Admin Dashboard** dikhega.

---

## 5. 401 / “Invalid email or password”

- Ye **login** (email + password) pe aata hai jab:  
  - Email galat hai, **ya**  
  - Password galat hai, **ya**  
  - Is email se koi user DB mein nahi hai (pehle signup nahi kiya).

**Fix:**  
- Pehle **Sign up** karo (OTP flow) with **orahulpanwar@gmail.com** → account banega + ADMIN_EMAIL ki wajah se **union_admin** ban jayega.  
- Ya jo email/password use kar rahe ho woh sahi hai confirm karo (DB / “Forgot password” agar baad mein add karo).

---

**Short:**  
- **ADMIN_EMAIL=orahulpanwar@gmail.com** backend `.env` (local + VPS) mein set karo.  
- Isi email se **Sign up (OTP)** ya **Login (OTP / password)** karo → app **Admin Dashboard** (Union Admin screen) dikhayegi.
