#!/usr/bin/env node
/**
 * Manually create admin user
 * Run: node create-admin-manual.js
 */
require('dotenv').config();
const { pool } = require('./src/config/database');
const bcrypt = require('bcryptjs');

(async () => {
  try {
    console.log('🔧 Creating admin user...');
    
    const email = 'admin@luharide.com';
    const password = 'Admin@123';
    const name = 'LuhaRide Admin';
    const role = 'union_admin';
    
    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);
    
    // Check if user exists
    const existing = await pool.query('SELECT id, role FROM users WHERE email = $1', [email]);
    
    if (existing.rows.length > 0) {
      // Update existing user
      await pool.query(
        'UPDATE users SET password_hash = $1, role = $2, name = $3, is_verified = TRUE, is_active = TRUE WHERE email = $4',
        [passwordHash, role, name, email]
      );
      console.log('✅ Admin user updated');
      console.log(`   Email: ${email}`);
      console.log(`   Password: ${password}`);
      console.log(`   Role: ${role}`);
    } else {
      // Create new user
      await pool.query(
        `INSERT INTO users (name, email, password_hash, role, is_verified, is_active, phone)
         VALUES ($1, $2, $3, $4, TRUE, TRUE, $5)`,
        [name, email, passwordHash, role, email]
      );
      console.log('✅ Admin user created');
      console.log(`   Email: ${email}`);
      console.log(`   Password: ${password}`);
      console.log(`   Role: ${role}`);
    }
    
    // Verify
    const verify = await pool.query('SELECT email, role FROM users WHERE email = $1', [email]);
    console.log('\n📋 Verification:');
    console.log(verify.rows[0]);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
})();
