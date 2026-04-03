/**
 * Upsert the platform admin user (email + password) for /api/simple-auth/login.
 * Uses ADMIN_EMAIL and ADMIN_INITIAL_PASSWORD from .env (see .env.example).
 *
 * Run from backend root: npm run create-admin
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const bcrypt = require('bcryptjs');
const { pool } = require('../src/config/database');

function phonePlaceholder() {
  const n = Date.now().toString();
  return `E${n.slice(-14)}`;
}

async function main() {
  const emailRaw = process.env.ADMIN_EMAIL;
  const password = process.env.ADMIN_INITIAL_PASSWORD;
  const name = (process.env.ADMIN_DISPLAY_NAME || 'Platform Admin').trim() || 'Platform Admin';

  if (!emailRaw || !String(emailRaw).trim()) {
    console.error('Missing ADMIN_EMAIL in .env');
    process.exit(1);
  }
  if (!password || !String(password).trim()) {
    console.error('Missing ADMIN_INITIAL_PASSWORD in .env (use quotes if the password contains #)');
    process.exit(1);
  }

  const email = String(emailRaw).toLowerCase().trim();
  const hash = await bcrypt.hash(String(password), 10);

  const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);

  if (existing.rows.length > 0) {
    await pool.query(
      `UPDATE users
       SET password_hash = $1,
           role = 'union_admin',
           name = $2,
           is_verified = TRUE,
           is_active = TRUE,
           updated_at = CURRENT_TIMESTAMP
       WHERE email = $3`,
      [hash, name, email]
    );
    console.log('Admin user updated:', email);
  } else {
    await pool.query(
      `INSERT INTO users (name, email, password_hash, role, is_verified, is_active, phone)
       VALUES ($1, $2, $3, 'union_admin', TRUE, TRUE, $4)`,
      [name, email, hash, phonePlaceholder()]
    );
    console.log('Admin user created:', email);
  }

  console.log('\nLogin in the app with Email + Password (simple auth).');
  console.log('ADMIN_EMAIL must match this email for union approval APIs.\n');
}

main()
  .catch((e) => {
    console.error(e.message || e);
    process.exit(1);
  })
  .finally(() => pool.end());
