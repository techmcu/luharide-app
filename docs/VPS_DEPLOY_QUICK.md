# VPS — 404 fix (login/signup API)

Agar app me **404** on `.../api/simple-auth/login` dikhe, **Flutter app sahi hai** — problem **server** par hai (purana code / galat process / nginx).

**`git pull` error: Password authentication is not supported?**  
→ GitHub HTTPS par ab **password** nahi — **SSH key** ya **Personal Access Token** chahiye. Step-by-step: [`VPS_GITHUB_GIT_PULL_SSH_OR_PAT.md`](./VPS_GITHUB_GIT_PULL_SSH_OR_PAT.md)

**`curl: Failed to connect to 127.0.0.1 port 3000`?**  
→ Gateway sun nahi raha (crash / galat port). Pehle: `pm2 logs luharide-api-gateway --lines 80`  
→ Port check: `ss -tlnp | grep 3000` ya `lsof -i :3000`  
→ `.env` me `PORT` / `GATEWAY_PORT` kisi aur port par ho to wahi `curl` karo.  
→ URL typo na ho: **`/api/simple-auth/ping`** ( **`ping4` nahi** ).

---

## 1) SSH se VPS par check

```bash
curl -sS http://127.0.0.1:3000/api/simple-auth/ping
```

- **JSON** `{"ok":true,"service":"simple-auth",...}` → route mount hai.
- **404** → is machine par **Node backend** purana hai ya galat folder se chal raha hai.

## 2) Update + restart

```bash
cd /path/to/luharide   # jahan `.git` ho — aksar `/var/www/luharide-backend` (parent), `backend` folder andar
git pull origin main
cd backend
npm ci
# pm2 use:
pm2 restart all
# ya direct:
node server.js
```

Phir dubara:

```bash
curl -sS http://127.0.0.1:3000/api/simple-auth/ping
curl -sS -X POST http://127.0.0.1:3000/api/simple-auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"wrong"}'
```

(Expected: **400/401** validation/wrong password — **404** nahi.)

## 3) Nginx

Agar **public** IP se 404 aur **localhost** se OK → nginx `proxy_pass` / path check karo.  
Example: `infra/nginx-reverse-proxy-luharide-api-gateway.example.conf`

## 4) Flutter local (bina VPS)

```bash
cd backend && node server.js
flutter run -d chrome --dart-define=USE_LOCAL_API=true
```

---

Zyaada detail: [`VPS_API_404_TROUBLESHOOTING.md`](./VPS_API_404_TROUBLESHOOTING.md)
