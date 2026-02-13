require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('./src/config/database');

async function run() {
  try {
    const sql = fs.readFileSync(
      path.join(__dirname, 'migrations', '004_bookings.sql'),
      'utf8'
    );
    await pool.query(sql);
    console.log('✅ Bookings table migration completed!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Failed:', error.message);
    process.exit(1);
  }
}

run();
