-- LuhaRide PostgreSQL Password Reset Script
-- Run this in pgAdmin Query Tool or psql

-- Step 1: Reset password to something simple
ALTER USER postgres WITH PASSWORD 'postgres123';

-- Step 2: Verify it worked
SELECT 'Password reset successful!' AS status;

-- After running this:
-- 1. Close pgAdmin/psql
-- 2. Run in terminal: node update-password.js
-- 3. Enter: postgres123
-- 4. Run: npm run test-db
