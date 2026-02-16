-- LUHARIDE DATABASE CLEANUP (SQL ONLY)
-- Run this in pgAdmin / DBeaver / psql on the "luharide" database ONLY. Do not run on sme_iot.
-- Keeps: demo@gmail.com, passenger@gmail.com, admin@luharide.com (passwords unchanged).
-- Deletes all other users and their data.

BEGIN;

-- Reviews
DELETE FROM reviews
WHERE driver_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com'))
   OR passenger_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com'));

-- Payments (skip if table does not exist)
DELETE FROM payments
WHERE booking_id IN (SELECT id FROM bookings WHERE passenger_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com')));

-- SOS logs
DELETE FROM sos_logs
WHERE user_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com'));

-- Location history
DELETE FROM location_history
WHERE trip_id IN (SELECT id FROM trips WHERE driver_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com')));

-- Notifications
DELETE FROM notifications
WHERE user_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com'));

-- Driver documents
DELETE FROM driver_documents
WHERE driver_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com'));

-- Driver verification requests
DELETE FROM driver_verification_requests
WHERE user_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com'));

-- Bookings
DELETE FROM bookings
WHERE passenger_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com'))
   OR trip_id IN (SELECT id FROM trips WHERE driver_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com')));

-- Trips
DELETE FROM trips
WHERE driver_id IN (SELECT id FROM users WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com'));

-- Users
DELETE FROM users
WHERE email NOT IN ('demo@gmail.com','passenger@gmail.com','admin@luharide.com');

COMMIT;

-- Verify
SELECT email, role FROM users ORDER BY email;
