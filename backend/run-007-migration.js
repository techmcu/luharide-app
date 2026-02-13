require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('./src/config/database');

async function run() {
  try {
    const sql = fs.readFileSync(
      path.join(__dirname, 'migrations', '007_driver_verification.sql'),
      'utf8'
    );
    await pool.query(sql);
    console.log('✅ Migration 007 completed');
    process.exit(0);
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    process.exit(1);
  }
}

run();
