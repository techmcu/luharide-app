/**
 * One-time script: Set a user to union_admin by email.
 * Run: node scripts/set-admin-by-email.js
 * Requires: .env in backend folder with DB_* and the email to make admin.
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const { pool } = require('../src/config/database');

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'orahulpanwar@gmail.com';

async function main() {
  const email = ADMIN_EMAIL.toLowerCase().trim();
  const result = await pool.query(
    "UPDATE users SET role = 'union_admin' WHERE email = $1 RETURNING id, email, role",
    [email]
  );
  if (result.rowCount === 0) {
    console.log(`No user found with email: ${email}. Create account first with this email.`);
    process.exit(1);
  }
  console.log(`Done. User ${email} is now union_admin. Logout and login again in the app to see Admin panel.`);
  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
