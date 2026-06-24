# luharide.cloud — Domain se App Live Karne Ka Step-by-Step

Domain **luharide.cloud** (Hostinger) ko VPS se jod kar app ko live chalane ke liye ye steps follow karo.

---

## Overview

| Step | Kya karna hai | Kahan |
|------|----------------|--------|
| 1 | Domain ko VPS IP pe point karna (DNS) | Hostinger |
| 2 | VPS pe Nginx + SSL (HTTPS) | VPS (SSH) |
| 3 | VPS ke .env mein CLIENT_URL = https://luharide.cloud | VPS |
| 4 | (Optional) Mobile app mein API URL domain pe switch karna | Code |

---

## Step 1: Hostinger pe DNS Set karo

1. **Hostinger** login → **Domains** → **luharide.cloud** → **DNS / Nameservers** (ya **Manage**).
2. **A Record** add/update karo:
   - **Type:** `A`
   - **Name:** `@` (ya blank — matlab luharide.cloud)
   - **Value / Points to:** `76.13.243.157` (tumhara VPS IP)
   - **TTL:** 300 ya 3600
3. (Optional) **www** ke liye bhi:
   - **Type:** `A`
   - **Name:** `www`
   - **Value:** `76.13.243.157`
4. **Save** karo. DNS propagate hone mein 5–30 min lag sakte hain.

Ab `http://luharide.cloud` browser mein VPS pe jana chahiye (jab tak VPS pe Nginx/port 80 setup nahi hoga, connection refused ya timeout aa sakta hai — normal hai).

---

## Step 2: VPS pe Nginx + SSL (HTTPS)

VPS pe SSH karo (PowerShell/terminal):

```bash
ssh root@76.13.243.157
```

Phir ye commands **ek ek karke** chalao:

### 2.1 Nginx install

```bash
apt update
apt install -y nginx certbot python3-certbot-nginx
```

### 2.2 Nginx config (domain → backend port 3000)

```bash
nano /etc/nginx/sites-available/luharide
```

Is **pura** content ko paste karo (Ctrl+Shift+V), save: **Ctrl+O**, Enter, **Ctrl+X**:

```nginx
server {
    listen 80;
    server_name luharide.cloud www.luharide.cloud;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 2.3 Site enable karo

```bash
ln -sf /etc/nginx/sites-available/luharide /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

### 2.4 SSL (HTTPS) — Let's Encrypt (free)

```bash
certbot --nginx -d luharide.cloud -d www.luharide.cloud
```

- Email daalo (renewal alerts ke liye).
- Terms accept karo.
- HTTP → HTTPS redirect “Yes” choose karo.

Iske baad **https://luharide.cloud** chalna chahiye aur tumhara backend API **https://luharide.cloud/api/...** pe available hoga.

---

## Step 3: VPS ke .env mein CLIENT_URL

VPS pe backend folder ke andar `.env` edit karo:

```bash
cd /var/www/luharide-backend/backend
nano .env
```

Ye line dhoondo aur is tarah set karo (localhost hata kar):

```env
CLIENT_URL=https://luharide.cloud
```

Agar line nahi hai to add kar do. Save: **Ctrl+O**, Enter, **Ctrl+X**.

Phir API restart:

```bash
pm2 restart luharide-api
```

---

## Step 4 (Optional): Mobile App — API URL domain pe

Abhi app **IP** use karti hai (`76.13.243.157:3000`). Domain + HTTPS use karne ke liye ye do files update karo:

**File 1:** `mobile/lib/core/constants/api_constants.dart`

- `baseUrl` ko change karo:
  - Pehle: `'http://76.13.243.157:3000/api'`
  - Baad: `'https://luharide.cloud/api'`

**File 2:** `mobile/lib/core/config/env_config.dart`

- `apiBaseUrl` → `'https://luharide.cloud/api'`
- `socketUrl` → `'https://luharide.cloud'`

Save karo, app dubara build/run karo. Ab app **https://luharide.cloud** se live API use karegi.

---

## Checklist

- [ ] Hostinger DNS: A record `@` → `76.13.243.157`
- [ ] VPS: Nginx install + luharide config + enable + reload
- [ ] VPS: `certbot --nginx` se SSL (https://luharide.cloud)
- [ ] VPS: `.env` mein `CLIENT_URL=https://luharide.cloud` + `pm2 restart luharide-api`
- [ ] (Optional) Mobile: `api_constants.dart` + `env_config.dart` mein https://luharide.cloud

---

## Summary

- **Domain (luharide.cloud)** = Hostinger pe DNS se VPS IP pe point.
- **Live** = VPS pe backend (port 3000) + Nginx (80/443) + SSL, aur VPS `.env` mein `CLIENT_URL=https://luharide.cloud`.
- **Local .env** (PC / env_full_copy_paste.txt) mein local URL rahne se **site live nahi rukti** — live sirf VPS wale .env + DNS + Nginx se hota hai.

Agar kisi step pe error aaye to exact error message bhejo, us hisaab se fix bata denge.
