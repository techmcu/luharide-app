# VPS pe ADMIN_EMAIL add karne ka step-by-step

**.env** file VPS pe hi hoti hai, isliye usme change tumhe SSH se karna padega. Neeche bilkul wahi steps hain jo follow karne hain.

---

## Option A: Sirf ek command (nano mat use karo)

SSH karo, phir ye **ek line** copy karke paste karo aur Enter dabao:

```bash
echo 'ADMIN_EMAIL=orahulpanwar@gmail.com' >> /var/www/luharide-backend/backend/.env
```

Phir backend restart (**--update-env zaroor use karo**):

```bash
cd /var/www/luharide-backend/backend && pm2 restart luharide-api --update-env
```

Iske baad app mein **logout → login** karo (orahulpanwar@gmail.com se). Admin panel dikhna chahiye.

---

## Agar ab bhi Admin panel nahi dikhe (Create account / Login ke baad bhi passenger hi dikhe)

Matlab DB mein tumhara user pehle se **passenger** bana hua hai. Usko ek baar **direct DB se admin banao**, phir logout → login karo.

**VPS pe SSH karke ye ek command chalao** (pura copy-paste karo):

```bash
cd /var/www/luharide-backend/backend && node -e "require('dotenv').config({path:require('path').join(process.cwd(),'.env')}); const {pool}=require('./src/config/database'); pool.query(\"UPDATE users SET role = 'union_admin' WHERE email = \$1 RETURNING id, email, role\", ['orahulpanwar@gmail.com']).then(r=>{console.log(r.rows[0]?'Done. '+r.rows[0].email+' is now union_admin. App mein logout then login karo.':'No user with this email.'); process.exit(0);}).catch(e=>{console.error(e); process.exit(1);});"
```

Phir **restart with env update**:

```bash
pm2 restart luharide-api --update-env
```

App mein **Logout** karo, phir **orahulpanwar@gmail.com** se dubara **Login** karo. Ab Admin panel dikhna chahiye.

---

## Option B: nano se manually add karna

### Step 1: CMD ya PowerShell kholo

Windows pe **Win + R** dabao → `cmd` likho → Enter (ya Cursor/VS Code ka Terminal kholo).

---

## Step 2: VPS pe login

Yeh command type karo (Enter dabao):

```
ssh root@76.13.243.157
```

- Password maange to **VPS ka password** daalo (Hostinger wala).
- Login hone ke baad kuch is tarah dikhega: `root@srv...:~#`

---

## Step 3: .env file kholo

Yeh command copy karke paste karo, phir Enter:

```
nano /var/www/luharide-backend/backend/.env
```

- Screen pe file ka content dikh jayega (NODE_ENV, PORT, DB_*, etc.).

---

## Step 4: Line add karo

- **Arrow keys** se upar niche chalate hue **JWT / REFRESH** wale lines ke **neeche** jao (jahan Email OTP wali lines shuru hoti hain).
- Wahan **ek nayi line** add karni hai.
- **Cursor** ko us line pe le jao jis pe likha hai: `EMAIL_USER=...` (ya `# Email OTP`).
- **Upar** wali khali line pe jao (ya EMAIL_USER se pehle).
- Ab ye **exactly** type karo (copy-paste bhi kar sakte ho):

```
ADMIN_EMAIL=orahulpanwar@gmail.com
```

- **Enter** dabao taaki ye alag line pe hi rahe.

**Dhyan:**  
- `=` ke around **space mat** rakhna.  
- Spelling sahi: `ADMIN_EMAIL` aur email sahi.

---

## Step 5: Save karo

- **Ctrl + O** dabao (Write Out / save).
- **Enter** dabao.
- **Ctrl + X** dabao (exit).

Ab wapas terminal prompt pe aa jayega.

---

## Step 6: Backend restart karo

Yeh **do** commands ek ek karke chalao (har ke baad Enter):

```
cd /var/www/luharide-backend/backend
```

```
pm2 restart luharide-api --update-env
```

"restarted" jaisa dikhe to theek hai.

---

## Step 7: App mein check karo

- App se **Logout** karo.
- Phir **Login** karo: **orahulpanwar@gmail.com** + OTP (ya password).
- Ab **Admin panel** (driver verification / taxi approval wala screen) dikhna chahiye.

---

**Short:**  
CMD → `ssh root@76.13.243.157` → password → `nano /var/www/luharide-backend/backend/.env` → JWT ke baad / Email OTP se pehle nayi line `ADMIN_EMAIL=orahulpanwar@gmail.com` add → **Ctrl+O** → Enter → **Ctrl+X** → `cd /var/www/luharide-backend/backend` → `pm2 restart luharide-api --update-env` → app mein logout → login.
