#!/usr/bin/env node
/**
 * EMERGENCY FIX - Admin Role
 * This will fix admin@luharide.com role to union_admin
 */
require('dotenv').config();
const { pool } = require('./src/config/database');
const bcrypt = require('bcryptjs');

console.log('🔧 Fixing admin user...\n');

(async () => {
  try {
    const email = 'admin@luharide.com';
    const password = 'Admin@123';
    
    // Check current state
    const check = await pool.query('SELECT email, role FROM users WHERE email = $1', [email]);
    
    if (check.rows.length > 0) {
      console.log('📋 Current state:');
      console.log('   Email:', check.rows[0].email);
      console.log('   Role:', check.rows[0].role);
      console.log('\n🔄 Fixing...\n');
    }
    
    // Hash password
    const passwordHash = await bcrypt.hash(password, 10);
    
    // Delete old user and create fresh
    await pool.query('DELETE FROM users WHERE email = $1', [email]);
    
    await pool.query(
      `INSERT INTO users (name, email, password_hash, role, is_verified, is_active, phone)
       VALUES ($1, $2, $3, $4, TRUE, TRUE, $5)`,
      ['LuhaRide Admin', email, passwordHash, 'union_admin', email]
    );
    
    // Verify
    const verify = await pool.query('SELECT email, role, is_active FROM users WHERE email = $1', [email]);
    
    console.log('✅ FIXED! New state:');
    console.log('   Email:', verify.rows[0].email);
    console.log('   Role:', verify.rows[0].role);
    console.log('   Active:', verify.rows[0].is_active);
    console.log('\n✨ Admin credentials:');
    console.log('   Email: admin@luharide.com');
    console.log('   Password: Admin@123');
    console.log('\n📱 Next steps:');
    console.log('   1. App mein LOGOUT karo');
    console.log('   2. Login karo with admin@luharide.com / Admin@123');
    console.log('   3. Admin Panel khul jayega!\n');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('\n💡 Solution:');
    console.error('   1. Check if PostgreSQL is running');
    console.error('   2. Check .env file has correct DB credentials');
    console.error('   3. Try: node server.js (to start backend first)\n');
    process.exit(1);
  } finally {
    await pool.end();
  }
})();
