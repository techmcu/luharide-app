# POST /trips 500 – Fix and deploy

The app uses **VPS API** (`76.13.243.157:3000`). The 500 happens on the **server**, not in the app.

## What was fixed (backend)

1. **Error handler** – Preserves PostgreSQL `err.code` and maps DB errors to 400/503 with a clear message instead of 500.
2. **Create trip** – Safe verification query, INSERT fallback, and handling for missing table/columns and NOT NULL violations.

## What you must do

1. **Deploy the updated backend to VPS**  
   Copy the latest `backend` folder to the server (e.g. `git pull` or upload files).

2. **On VPS, restart the API**  
   ```bash
   cd /var/www/luharide-backend/backend
   pm2 restart luharide-api --update-env
   ```

3. **If the error was “schema/migrations”**  
   On VPS, run migrations:
   ```bash
   cd /var/www/luharide-backend/backend
   npm run migrate
   ```
   Then restart again: `pm2 restart luharide-api --update-env`.

After this, failed create-trip calls should return **400** or **503** with a message (e.g. “Missing required data”, “Run migrations”). The app will show that message in the red SnackBar.

## Testing against local backend (optional)

To test with your **local** Node server instead of VPS:

- In `mobile/lib/core/config/env_config.dart`, set:
  - `apiBaseUrl = 'http://10.0.2.2:3000/api'` (Android emulator), or  
  - `apiBaseUrl = 'http://localhost:3000/api'` (if your setup uses it).
- Run the backend locally: `cd backend && node server.js` (or `npm start`).
- Ensure local DB has migrations run (`npm run migrate`).

Then create a trip again; any error message from the backend will appear in the app.
