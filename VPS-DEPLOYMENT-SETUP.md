# VPS Deployment - GitHub pe Alag Dikhane Ke Liye

## Problem
Deployments tab mein Railway (luminous-adventure) dikh raha tha, VPS nahi.

## Solution
Workflow **"vps"** environment use karega - alag dikhega Railway se.

---

## Step 1: "vps" Environment Banao

1. https://github.com/techmcu/luharide-app → **Settings** → **Environments**
2. **New environment** pe click
3. Name: `vps`
4. **Configure environment** → Save

---

## Step 2: Workflow File GitHub pe Add karo (browser se)

Token mein workflow scope nahi hai, isliye browser se add karo:

1. https://github.com/techmcu/luharide-app/new/main
2. File name: `.github/workflows/deploy-vps.yml`
3. Neeche wala content paste karo (deploy-vps.yml file se copy)
4. **Commit new file** pe click

---

## Step 3: Push (baaki changes)

```powershell
cd D:\cur\luharide
git add VPS-DEPLOYMENT-SETUP.md
git commit -m "chore: VPS deployment setup"
git push
```

---

## Result

Deployments tab: **vps** (Hostinger) alag dikhega Railway se.
