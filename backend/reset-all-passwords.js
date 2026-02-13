require('dotenv').config();
const { pool } = require('./src/config/database');
const bcrypt = require('bcryptjs');

async function resetPasswords() {
  try {
    console.log('\n🔧 Resetting all passwords to "demo123"...\n');
    
    const password = 'demo123';
    const hashedPassword = await bcrypt.hash(password, 10);
    
    // Update all users
    const result = await pool.query(
      `UPDATE users 
       SET password_hash = $1, 
           is_verified = true, 
           is_active = true
       RETURNING email, role, name`,
      [hashedPassword]
    );
    
    console.log('✅ Password reset complete!\n');
    console.log('📊 Updated Users:\n');
    
    result.rows.forEach(user => {
      console.log(`${user.role.toUpperCase().padEnd(15)} | ${user.email.padEnd(25)} | ${user.name}`);
    });
    
    console.log('\n✅ All users can now login with password: demo123\n');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

resetPasswords();
