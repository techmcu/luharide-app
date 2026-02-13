require('dotenv').config();
const { pool } = require('./src/config/database');

async function checkUsers() {
  try {
    const result = await pool.query('SELECT email, role, name FROM users ORDER BY role, email');
    
    console.log('\n📊 All Users in Database:\n');
    result.rows.forEach(user => {
      console.log(`${user.role.toUpperCase().padEnd(15)} | ${user.email.padEnd(25)} | ${user.name}`);
    });
    
    console.log(`\nTotal: ${result.rows.length} users\n`);
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkUsers();
