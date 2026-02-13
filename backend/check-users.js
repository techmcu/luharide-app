require('dotenv').config();
const { pool } = require('./src/config/database');

async function checkUsers() {
  try {
    const result = await pool.query(`
      SELECT id, name, email, role, is_verified, is_active, created_at 
      FROM users 
      ORDER BY created_at DESC 
      LIMIT 10
    `);
    
    console.log('\n📊 Recent Users in Database:\n');
    console.log('Total users:', result.rowCount);
    console.log('\n');
    
    result.rows.forEach((user, index) => {
      console.log(`${index + 1}. ${user.name}`);
      console.log(`   UUID: ${user.id}`);
      console.log(`   Email: ${user.email}`);
      console.log(`   Role: ${user.role}`);
      console.log(`   Verified: ${user.is_verified}`);
      console.log(`   Active: ${user.is_active}`);
      console.log(`   Created: ${user.created_at}`);
      console.log('');
    });
    
    // Count by role
    const roleCount = await pool.query(`
      SELECT role, COUNT(*) as count 
      FROM users 
      GROUP BY role
    `);
    
    console.log('📈 Users by Role:');
    roleCount.rows.forEach(row => {
      console.log(`   ${row.role}: ${row.count}`);
    });
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkUsers();
