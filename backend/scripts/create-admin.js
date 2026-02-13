/**
 * Create Admin User for LuhaRide
 * Run: node scripts/create-admin.js
 * Creates admin@luharide.com / Admin@123 (change in production!)
 */
require('dotenv').config();
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/luharide'
});

async function createAdmin() {
  const email = 'admin@luharide.com';
  const password = 'Admin@123';
  const name = 'LuhaRide Admin';

  const hash = await bcrypt.hash(password, 10);

  const existing = await pool.query(
    "SELECT id FROM users WHERE email = $1",
    [email]
  );

  if (existing.rows.length > 0) {
    await pool.query(
      "UPDATE users SET password_hash = $1, role = 'union_admin', name = $2 WHERE email = $3",
      [hash, name, email]
    );
    console.log('Admin user updated.');
  } else {
    await pool.query(
      `INSERT INTO users (name, email, password_hash, role, phone, is_verified, is_active)
       VALUES ($1, $2, $3, 'union_admin', $4, TRUE, TRUE)`,
      [name, email, hash, email]
    );
    console.log('Admin user created.');
  }

  console.log('\n========================================');
  console.log('  LuhaRide ADMIN CREDENTIALS');
  console.log('========================================');
  console.log('  Email:    admin@luharide.com');
  console.log('  Password: Admin@123');
  console.log('========================================');
  console.log('  Use these to login as Admin in the app.');
  console.log('  Admin can: Approve/Reject drivers, manage rides.');
  console.log('========================================\n');
  process.exit(0);
}

createAdmin().catch(e => {
  console.error(e);
  process.exit(1);
});
