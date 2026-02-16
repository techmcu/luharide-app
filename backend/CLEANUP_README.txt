LUHARIDE DATABASE CLEANUP - HOW TO RUN
======================================

This cleans ONLY the "luharide" database. SmeIot / sme_iot is never touched.

Keeps these 3 accounts (passwords unchanged):
  - demo@gmail.com
  - passenger@gmail.com
  - admin@luharide.com

Deletes all other users and all their data.

STEPS:
------
1. In luharide/backend folder, ensure your .env has:

   DB_HOST=localhost
   DB_PORT=5432
   DB_NAME=luharide
   DB_USER=postgres
   DB_PASSWORD=your_actual_password

2. Open terminal / PowerShell and go to backend folder:

   cd D:\cur\luharide\backend

3. Run the script:

   node cleanup-luharide-db.js

4. You should see "Connected to database: luharide" and then list of deleted rows. At the end it will show only 3 users left.

Done.
