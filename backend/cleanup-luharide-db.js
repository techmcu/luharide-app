require('dotenv').config();

/**
 * LUHARIDE DATABASE CLEANUP
 * -------------------------
 * - Connects ONLY to database: luharide (SmeIot / sme_iot is NEVER touched)
 * - Keeps ONLY these 3 accounts (passwords unchanged):
 *   • demo@gmail.com
 *   • passenger@gmail.com
 *   • admin@luharide.com
 * - Deletes all other users and all their data (trips, bookings, notifications, etc.)
 *
 * Run from luharide/backend folder:
 *   set DB_PASSWORD=YourPassword && node cleanup-luharide-db.js
 * Or put DB_PASSWORD in .env and run: node cleanup-luharide-db.js
 */

const { Pool } = require('pg');

const KEEP_EMAILS = ['demo@gmail.com', 'passenger@gmail.com', 'admin@luharide.com'];

const DB_NAME = process.env.DB_NAME || 'luharide';

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT, 10) || 5432,
  database: DB_NAME,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || '',
});

async function runQuery(client, sql, label) {
  try {
    const res = await client.query(sql);
    console.log(`  ${label}: ${res.rowCount} row(s) affected`);
    return res.rowCount;
  } catch (err) {
    if (err.code === '42P01') {
      console.log(`  ${label}: table does not exist (skipped)`);
      return 0;
    }
    throw err;
  }
}

async function main() {
  console.log('\n=== LUHARIDE DB CLEANUP ===');
  console.log('Database: luharide ONLY (sme_iot will not be touched)\n');
  console.log('Keeping only:', KEEP_EMAILS.join(', '));

  if (!process.env.DB_PASSWORD) {
    console.error('\nError: Set DB_PASSWORD in .env or before running.');
    console.error('Example (PowerShell): $env:DB_PASSWORD="YourPassword"; node cleanup-luharide-db.js');
    process.exit(1);
  }

  const client = await pool.connect();
  try {
    const dbCheck = await client.query('SELECT current_database()');
    const dbName = dbCheck.rows[0].current_database;
    if (dbName !== DB_NAME || dbName === 'sme_iot') {
      console.error(`\nSafety stop: connected to database "${dbName}". This script runs ONLY on "luharide". Aborting.`);
      process.exit(1);
    }
    console.log('Connected to database:', dbName, '\n');

    // Run each DELETE without a single big transaction, so "table does not exist" only skips that step
    const sub = `SELECT id FROM users WHERE email NOT IN ('${KEEP_EMAILS.join("','")}')`;
    const tripSub = `SELECT id FROM trips WHERE driver_id IN (${sub})`;

    await runQuery(client, `DELETE FROM reviews WHERE driver_id IN (${sub}) OR passenger_id IN (${sub})`, 'reviews');
    await runQuery(client, `DELETE FROM payments WHERE booking_id IN (SELECT id FROM bookings WHERE passenger_id IN (${sub}))`, 'payments');
    await runQuery(client, `DELETE FROM sos_logs WHERE user_id IN (${sub})`, 'sos_logs');
    await runQuery(client, `DELETE FROM location_history WHERE trip_id IN (${tripSub})`, 'location_history');
    await runQuery(client, `DELETE FROM notifications WHERE user_id IN (${sub})`, 'notifications');
    await runQuery(client, `DELETE FROM driver_documents WHERE driver_id IN (${sub})`, 'driver_documents');
    await runQuery(client, `DELETE FROM driver_verification_requests WHERE user_id IN (${sub})`, 'driver_verification_requests');
    await runQuery(client, `DELETE FROM refresh_tokens WHERE user_id IN (${sub})`, 'refresh_tokens');
    await runQuery(client, `DELETE FROM login_history WHERE user_id IN (${sub})`, 'login_history');
    await runQuery(client, `DELETE FROM emergency_contacts WHERE user_id IN (${sub})`, 'emergency_contacts');

    await runQuery(client, `DELETE FROM bookings WHERE passenger_id IN (${sub}) OR trip_id IN (${tripSub})`, 'bookings');
    await runQuery(client, `DELETE FROM trips WHERE driver_id IN (${sub})`, 'trips');
    await runQuery(client, `DELETE FROM users WHERE email NOT IN ('${KEEP_EMAILS.join("','")}')`, 'users');

    console.log('\nDone. Verifying...');
    const r = await client.query("SELECT email, role FROM users ORDER BY email");
    console.log('Remaining users:', r.rows.length);
    r.rows.forEach(row => console.log('  -', row.email, '|', row.role));
    console.log('\nCleanup complete.\n');
  } catch (err) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    console.error('Cleanup failed:', err.message);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

main();
