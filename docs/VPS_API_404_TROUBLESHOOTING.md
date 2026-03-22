# VPS par `/api/...` 404

**Quick deploy steps:** [`VPS_DEPLOY_QUICK.md`](./VPS_DEPLOY_QUICK.md)

---

## Details

Client URL sahi hai (e.g. `http://YOUR_VPS:3000/api/simple-auth/login`). **404** ka matlab HTTP server ne jawab diya lekin **Express route match nahi hua**.

## Turant check (browser ya curl)

```text
GET http://YOUR_IP:3000/health
GET http://YOUR_IP:3000/api
GET http://YOUR_IP:3000/api/simple-auth/ping
```

- **`/api/simple-auth/ping`** → `{"ok":true,"service":"simple-auth",...}`  
  - Agar **404** → VPS par **purana code** (deploy / PM2 restart) ya port par **koi aur app** chal rahi hai.
- **`/health`** OK but **`/api/simple-auth/ping`** 404 → Node app galat version / routes mount nahi.

## Common fixes

1. **Latest code deploy** + **`pm2 restart all`** (ya jo process `server.js` / gateway chala raha ho).
2. **Nginx** `proxy_pass` — path **poora** Node tak bhejna chahiye (trailing slash mistake se `/api` double/strip ho sakta hai). Dekho: `infra/nginx-reverse-proxy-luharide-api-gateway.example.conf`.
3. **Firewall** — sirf 3000 expose ho; andar se `curl localhost:3000/api/simple-auth/ping` VPS SSH par chalao.

## Flutter

Production build: `USE_LOCAL_API` **false** (default) → `EnvConfig` VPS URL use karega.  
Override: `--dart-define=API_BASE_URL=https://api.yourdomain.com/api`.
