require('dotenv').config();
const { pool } = require('./src/config/database');

async function checkDriverRole() {
  try {
    const result = await pool.query(
      "SELECT name, email, role FROM users WHERE email LIKE '%driver%' OR role = 'driver'"
    );

    console.log('\n📊 Driver Users:\n');
    console.log(JSON.stringify(result.rows, null, 2));
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

checkDriverRole();
