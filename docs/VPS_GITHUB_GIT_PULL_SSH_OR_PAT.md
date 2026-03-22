# VPS par `git pull` — GitHub password ab kaam nahi (SSH ya PAT)

**Error:** `Password authentication is not supported for Git operations`

GitHub ne HTTPS par **password** band kar diya. Server par **`git pull`** ke liye **SSH key** ya **Personal Access Token (PAT)** use karo.

---

## Option A — SSH (recommended, ek baar setup)

### 1) Server par key banao

```bash
ssh-keygen -t ed25519 -C "vps-luharide" -f ~/.ssh/id_ed25519_github -N ""
cat ~/.ssh/id_ed25519_github.pub
```

### 2) Public key GitHub par add karo

GitHub → **Settings** → **SSH and GPG keys** → **New SSH key** → paste → Save.

### 3) Remote HTTPS se SSH par badlo

```bash
cd /var/www/luharide-backend   # apna repo root
git remote set-url origin git@github.com:techmcu/luharide-app.git
ssh -T git@github.com
```

`Hi techmcu! You've successfully authenticated...` aana chahiye.

### 4) Pull

```bash
cd backend   # ya jahan package.json hai
git pull origin main
```

---

## Option B — HTTPS + Personal Access Token (PAT)

1. GitHub → **Settings** → **Developer settings** → **Personal access tokens**  
   - Fine-grained ya Classic → **repo** scope (read at least).

2. Server par:

```bash
git pull https://github.com/techmcu/luharide-app.git
```

Username: `techmcu`  
Password: **token paste** (GitHub password nahi)

Ya credential store:

```bash
git config --global credential.helper store
git pull
# ek baar username + token do — save ho jayega
```

---

## PM2: `Use --update-env`

Jab **`.env`** ya **PM2 ecosystem** mein **naya env** (jaise `TRUST_PROXY`) add karo aur purana process restart ho, kabhi-kabhi purana env cache rehta hai.

```bash
cd /var/www/luharide-backend/backend
pm2 restart all --update-env
pm2 save
```

Pehle **`git pull`** se latest code + ecosystem aana zaroori hai.

---

## Order (short)

1. **SSH ya PAT** fix → `git pull`  
2. `npm install` (agar package.json badla ho)  
3. `pm2 restart all --update-env`  
4. `pm2 save`
