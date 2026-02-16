require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('./src/config/database');

async function run() {
  try {
    const sql = fs.readFileSync(
      path.join(__dirname, 'migrations', '008_vehicle_model_id.sql'),
      'utf8'
    );
    await pool.query(sql);
    console.log('✅ Migration 008 (vehicle_model_id) completed');
    process.exit(0);
  } catch (err) {
    console.error('❌ Migration failed:', err.message);
    process.exit(1);
  }
}

run();
