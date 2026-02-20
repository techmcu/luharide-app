# Admin panel nahi khul raha – fix (orahulpanwar@gmail.com)

Account to bana lekin **Admin panel** (jahan driver approval hota hai) nahi dikh raha – isliye kyunki app **VPS** pe chal rahi hai aur wahan pe ya to **ADMIN_EMAIL** set nahi tha ya **purana code** chal raha tha.

---

## Option A: VPS pe ADMIN_EMAIL + ek baar logout/login (recommended)

### 1. VPS pe .env mein ADMIN_EMAIL add karo

SSH:
```bash
ssh root@76.13.243.157
```

Edit:
```bash
nano /var/www/luharide-backend/backend/.env
```

Jahan bhi (e.g. Email OTP ke upar) ye line add karo:
```env
ADMIN_EMAIL=orahulpanwar@gmail.com
```
Save: Ctrl+O, Enter, Ctrl+X.

### 2. Latest code deploy karo (agar abhi tak push nahi kiya)

Tumhare PC se (jahan repo hai):
```bash
cd D:\cur\luharide
git add -A
git commit -m "fix: ADMIN_EMAIL for admin panel"
git push origin main
```
(VPS pe workflow run hoga, code update ho jayega.)

### 3. VPS pe backend restart

```bash
cd /var/www/luharide-backend/backend
pm2 restart luharide-api
```

### 4. App mein logout → phir login

- App kholo → **Profile** (ya jahan bhi **Logout** hai) → **Logout**.
- Phir **Login** → Email: **orahulpanwar@gmail.com** → **Send OTP** → OTP daalo → verify.

Is login pe backend tumhare user ko **union_admin** bana dega (ADMIN_EMAIL match) aur response mein **role: union_admin** aayega. App phir **Admin / Union Admin** screen (driver verification, approvals) dikhayegi.

---

## Option B: Sirf existing user ko DB mein admin banao (quick fix)

Agar abhi VPS pe code deploy nahi karna / ADMIN_EMAIL logic use nahi karna, to **sirf is email wale user ko DB mein admin bana do**, phir app mein **logout → login** karo.

### VPS pe database mein run karo

SSH:
```bash
ssh root@76.13.243.157
```

PostgreSQL (DB name/user .env jaisa ho, e.g. luharide):
```bash
cd /var/www/luharide-backend/backend
node -e "
require('dotenv').config();
const { pool } = require('./src/config/database');
(async () => {
  const r = await pool.query(\"UPDATE users SET role = 'union_admin' WHERE email = 'orahulpanwar@gmail.com' RETURNING id, email, role\");
  console.log(r.rowCount ? 'Done. User is now union_admin.' : 'No user found with this email.');
  process.exit(0);
})();
"
```

Ya direct psql se (agar pata ho DB password):
```bash
psql -U luharide_user -d luharide -c "UPDATE users SET role = 'union_admin' WHERE email = 'orahulpanwar@gmail.com';"
```

### Phir app mein

- **Logout** karo.
- **Login** karo (orahulpanwar@gmail.com + OTP ya password).

Ab token mein **role = union_admin** aayega, **Admin panel** (driver approvals wala screen) open ho jana chahiye.

---

## Short

- **Admin panel** = wahi screen jahan **driver verification / taxi approval** hota hai.
- Problem: is email ka **role** DB mein **passenger** tha, isliye passenger wala dashboard dikh raha tha.
- Fix: **VPS .env** mein `ADMIN_EMAIL=orahulpanwar@gmail.com` + latest code deploy + **pm2 restart** → phir app mein **logout → login** (Option A).
- Ya sirf DB mein `UPDATE users SET role = 'union_admin' WHERE email = 'orahulpanwar@gmail.com';` run karo, phir **logout → login** (Option B).
