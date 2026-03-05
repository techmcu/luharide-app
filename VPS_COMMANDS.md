# LuhaRide VPS Commands – Backend & Server

Server IP: `76.13.243.157`

---

## 1. SSH Login

```bash
ssh root@76.13.243.157
# password: (root ka password jo Hostinger panel se set kiya hai)
```

---

## 2. Backend project folder

```bash
cd /var/www/luharide-backend
ls
```

Important folders:

- `backend/` – Node.js API code  
- `mobile/` – Flutter app code (reference)  
- `.env` – backend config: `backend/.env`

---

## 3. Git commands (code update)

Remote check:

```bash
cd /var/www/luharide-backend
git remote -v
```

Latest commit dekhna:

```bash
git log -1 --oneline
```

Git se latest code lana:

```bash
cd /var/www/luharide-backend
git pull origin main
```

---

## 4. Backend restart (PM2)

PM2 processes dekhna:

```bash
pm2 list
```

API process restart (example name: `luharide-api`):

```bash
pm2 restart luharide-api
```

Specific process logs:

```bash
pm2 logs luharide-api
```

---

## 5. PostgreSQL login shortcut

Backend `.env` se:

- `DB_NAME=luharide`  
- `DB_USER=luharide_user`  
- `DB_PASSWORD=rahul@123`

PSQL login:

```bash
cd /var/www/luharide-backend
PGPASSWORD='rahul@123' psql -U luharide_user -d luharide -h localhost
```

PSQL se bahar:

```sql
\q
```

---

## 6. Common maintenance patterns

- **Config dekhna**:

  ```bash
  cd /var/www/luharide-backend
  cat backend/.env
  ```

- **Node modules reinstall (agar dependency issue ho)**:

  ```bash
  cd /var/www/luharide-backend/backend
  npm install
  ```

- **Migrations run karna (agar script set hai)**:

  ```bash
  cd /var/www/luharide-backend/backend
  npm run migrate
  ```

